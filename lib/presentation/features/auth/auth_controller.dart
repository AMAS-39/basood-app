import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import '../../../domain/entities/user_entity.dart';
import '../../providers/use_case_providers.dart';
import '../../providers/di_providers.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/jwt_utils.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);

class AuthState {
  final bool isLoading;
  final bool isInitialized; // New field to track if we've checked stored tokens
  final UserEntity? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isInitialized = false, // Default to false
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized, // Include new field
    UserEntity? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized, // Copy new field
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(const AuthState());

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final loginUC = ref.read(loginMobileUCProvider);
      final (user, tokens) = await loginUC.call(
        username: username,
        password: password,
      );

      // Store tokens
      ref.read(accessTokenProvider.notifier).state = tokens.accessToken;
      ref.read(refreshTokenProvider.notifier).state = tokens.refreshToken;

      // Store in secure storage
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'access_token', value: tokens.accessToken);
      await storage.write(key: 'refresh_token', value: tokens.refreshToken);
      await storage.write(
        key: 'user_data',
        value: jsonEncode({
          'id': user.id,
          'name': user.name,
          'role': user.role,
          'isToCustomer': user.isToCustomer,
          'email': user.email,
          'phone': user.phone,
          'address': user.address,
          'supplierId': user.supplierId,
        }),
      );

      // Send FCM token to backend after successful login
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await FirebaseService.sendTokenToBackend(fcmToken);
        }
      } catch (e) {
        print('⚠️ Failed to send FCM token after login: $e');
        // Don't fail login if FCM token send fails
      }

      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    // Try to revoke token on server, but don't fail if it doesn't work
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.revokeToken();
    } catch (e) {
      // Ignore logout errors - token might already be invalid/expired
      print('Token revocation failed (this is usually OK): $e');
    }

    // Always clear local data regardless of server response
    // Clear tokens from memory
    ref.read(accessTokenProvider.notifier).state = null;
    ref.read(refreshTokenProvider.notifier).state = null;

    // Clear from storage
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'user_data');

    // Reset auth state - this will trigger navigation to login screen
    state = const AuthState(isInitialized: true);
  }

  Future<void> loadStoredTokens() async {
    state = state.copyWith(isLoading: true);

    try {
      final storage = ref.read(secureStorageProvider);
      final accessToken = await storage.read(key: 'access_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      final userJson = await storage.read(key: 'user_data');

      // Check if we have an access token (trust backend/frontend for expiration)
      if (accessToken != null && accessToken.isNotEmpty) {
        // Token exists, restore session (backend/frontend will handle expiration)
        ref.read(accessTokenProvider.notifier).state = accessToken;

        // Restore refresh token if available
        if (refreshToken != null && refreshToken.isNotEmpty) {
          ref.read(refreshTokenProvider.notifier).state = refreshToken;
        }

        // Try to restore user data from storage first
        UserEntity? user;
        if (userJson != null) {
          try {
            final userData = jsonDecode(userJson);
            user = UserEntity(
              id: userData['id'],
              name: userData['name'],
              role: userData['role'],
              isToCustomer: userData['isToCustomer'],
              email: userData['email'],
              phone: userData['phone'],
              address: userData['address'],
              supplierId: userData['supplierId'],
            );
          } catch (e) {
            debugPrint('⚠️ Error parsing stored user data: $e');
            // Continue - will try to extract from token
          }
        }

        // If we don't have user data, try to extract from token
        if (user == null) {
          try {
            final tokenPayload = JwtUtils.decodeToken(accessToken);
            if (tokenPayload != null) {
              int? supplierId;
              if (tokenPayload['supplierId'] != null) {
                final supplierIdValue = tokenPayload['supplierId'];
                if (supplierIdValue is int) {
                  supplierId = supplierIdValue;
                } else if (supplierIdValue is String) {
                  supplierId = int.tryParse(supplierIdValue);
                }
              }

              user = UserEntity(
                id:
                    tokenPayload['sub']?.toString() ??
                    tokenPayload['id']?.toString() ??
                    '',
                name:
                    tokenPayload['name']?.toString() ??
                    tokenPayload['username']?.toString() ??
                    '',
                role: tokenPayload['role']?.toString() ?? '',
                isToCustomer: tokenPayload['isToCustomer'] ?? false,
                email: tokenPayload['email']?.toString() ?? '',
                phone: tokenPayload['phone']?.toString() ?? '',
                address: tokenPayload['address']?.toString() ?? '',
                supplierId: supplierId,
              );

              // Save user data for next time
              await storage.write(
                key: 'user_data',
                value: jsonEncode({
                  'id': user.id,
                  'name': user.name,
                  'role': user.role,
                  'isToCustomer': user.isToCustomer,
                  'email': user.email,
                  'phone': user.phone,
                  'address': user.address,
                  'supplierId': user.supplierId,
                }),
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error extracting user from token: $e');
          }
        }

        // Session restored successfully
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          user:
              user, // Can be null if we can't extract user info, but token is valid
        );
        debugPrint('✅ Session restored successfully');
      } else {
        // No valid token, user is not logged in
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          user: null,
        );
        debugPrint('ℹ️ No valid token found, user not logged in');
      }
    } catch (e) {
      // Error loading tokens, but don't clear everything - might be a temporary issue
      debugPrint('❌ Error loading tokens: $e');
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        user: null,
        error: e.toString(),
      );
    }
  }

  /// Sync tokens from WebView login (when user logs in via web page)
  Future<void> syncTokensFromWebView({
    required String accessToken,
    String? refreshToken,
  }) async {
    try {
      // Store in secure storage FIRST - CRITICAL for persistence across app restarts
      // This ensures tokens are saved even if provider update fails
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'access_token', value: accessToken);
      debugPrint('✅ Access token saved to secure storage from WebView');

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: refreshToken);
        debugPrint('✅ Refresh token saved to secure storage from WebView');
      }

      // Update provider state AFTER saving to storage
      ref.read(accessTokenProvider.notifier).state = accessToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        ref.read(refreshTokenProvider.notifier).state = refreshToken;
      }

      // Try to extract user info from token
      try {
        final tokenPayload = JwtUtils.decodeToken(accessToken);
        if (tokenPayload != null) {
          // Try to create user entity from token payload
          // Note: Token might not have all user fields, so we use what's available
          int? supplierId;
          if (tokenPayload['supplierId'] != null) {
            final supplierIdValue = tokenPayload['supplierId'];
            if (supplierIdValue is int) {
              supplierId = supplierIdValue;
            } else if (supplierIdValue is String) {
              supplierId = int.tryParse(supplierIdValue);
            }
          }

          final user = UserEntity(
            id:
                tokenPayload['sub']?.toString() ??
                tokenPayload['id']?.toString() ??
                '',
            name:
                tokenPayload['name']?.toString() ??
                tokenPayload['username']?.toString() ??
                '',
            role: tokenPayload['role']?.toString() ?? '',
            isToCustomer: tokenPayload['isToCustomer'] ?? false,
            email: tokenPayload['email']?.toString() ?? '',
            phone: tokenPayload['phone']?.toString() ?? '',
            address: tokenPayload['address']?.toString() ?? '',
            supplierId: supplierId,
          );

          // Store user data
          await storage.write(
            key: 'user_data',
            value: jsonEncode({
              'id': user.id,
              'name': user.name,
              'role': user.role,
              'isToCustomer': user.isToCustomer,
              'email': user.email,
              'phone': user.phone,
              'address': user.address,
              'supplierId': user.supplierId,
            }),
          );

          // Update state with user
          state = state.copyWith(isInitialized: true, user: user);
        } else {
          // Can't decode token, but tokens are stored
          // User will be loaded on next app restart if backend provides user info
          state = state.copyWith(isInitialized: true, user: null);
        }
      } catch (e) {
        // Can't decode token, but tokens are stored
        print('⚠️ Could not decode user info from token: $e');
        state = state.copyWith(isInitialized: true, user: null);
      }

      print('✅ Tokens synced from WebView successfully');
    } catch (e) {
      print('❌ Error syncing tokens from WebView: $e');
    }
  }
}
