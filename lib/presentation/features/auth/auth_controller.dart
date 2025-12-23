import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import '../../../domain/entities/user_entity.dart';
import '../../providers/use_case_providers.dart';
import '../../providers/di_providers.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/jwt_utils.dart';
import '../../../core/utils/file_logger.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

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

  AuthController(this.ref) : super(const AuthState()) {
    // Listen for FCM token refresh and send with user ID if logged in
    _setupTokenRefreshListener();
  }
  
  void _setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        if (state.user != null && state.user!.id.isNotEmpty) {
          await FirebaseService.sendTokenToBackend(
            newToken,
            state.user!.id,
          );
        }
      } catch (e) {
        // Ignore token refresh errors
      }
    });
  }

  Future<void> loginCC({
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
      await storage.write(key: 'user_data', value: jsonEncode({
        'id': user.id,
        'name': user.name,
        'role': user.role,
        'isToCustomer': user.isToCustomer,
        'email': user.email,
        'phone': user.phone,
        'address': user.address,
        'supplierId': user.supplierId,
      }));
      
      // Send FCM token to backend after successful login
      FileLogger.log('🔐 Login successful - Preparing to send FCM token');
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        FileLogger.log('   FCM token retrieved: ${fcmToken != null}');
        FileLogger.log('   User ID: ${user.id}');
        FileLogger.log('   User ID is not empty: ${user.id.isNotEmpty}');
        
        if (fcmToken != null && user.id.isNotEmpty) {
          FileLogger.log('   ✅ Calling sendTokenToBackend...');
          await FirebaseService.sendTokenToBackend(fcmToken, user.id);
        } else {
          FileLogger.log('   ⚠️ Cannot send FCM token - token: ${fcmToken != null}, userId: ${user.id.isNotEmpty}');
        }
      } catch (e) {
        FileLogger.log('   ❌ Error in FCM token send flow: $e');
        // Don't fail login if FCM token send fails
      }
      
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    // Get user ID before clearing state (for FCM token cleanup)
    final userId = state.user?.id;
    
    // Try to revoke token on server, but don't fail if it doesn't work
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.revokeToken();
    } catch (e) {
      // Ignore logout errors - token might already be invalid/expired
      print('Token revocation failed (this is usually OK): $e');
    }
    
    // Clear FCM token sent flag (if user was logged in)
    if (userId != null && userId.isNotEmpty) {
      try {
        await FirebaseService.clearTokenSentFlag(userId);
      } catch (e) {
        print('⚠️ Error clearing FCM token flag on logout: $e');
        // Don't fail logout if FCM cleanup fails
      }
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
    FileLogger.log('🔄 ========== loadStoredTokens CALLED ==========');
    state = state.copyWith(isLoading: true);
    
    try {
      final storage = ref.read(secureStorageProvider);
      
      final accessToken = await storage.read(key: 'access_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      final userJson = await storage.read(key: 'user_data');
      
      FileLogger.log('   Checking stored tokens...');
      FileLogger.log('   Access token found: ${accessToken != null}');
      FileLogger.log('   Refresh token found: ${refreshToken != null}');
      FileLogger.log('   User data found: ${userJson != null}');
      
      if (accessToken != null && refreshToken != null && userJson != null) {
        FileLogger.log('   ✅ All tokens found - User is logged in');
        ref.read(accessTokenProvider.notifier).state = accessToken;
        ref.read(refreshTokenProvider.notifier).state = refreshToken;
        
        try {
          final userData = jsonDecode(userJson);
          final user = UserEntity(
            id: userData['id'],
            name: userData['name'],
            role: userData['role'],
            isToCustomer: userData['isToCustomer'],
            email: userData['email'],
            phone: userData['phone'],
            address: userData['address'],
            supplierId: userData['supplierId'],
          );
          
          state = state.copyWith(
            isLoading: false,
            isInitialized: true,
            user: user,
          );
          
          // Send FCM token to backend if user is already logged in
          FileLogger.log('   🔄 Loading stored tokens - Preparing to send FCM token');
          try {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            FileLogger.log('   FCM token retrieved: ${fcmToken != null}');
            FileLogger.log('   User ID: ${user.id}');
            
            if (fcmToken != null && user.id.isNotEmpty) {
              FileLogger.log('   ✅ Calling sendTokenToBackend...');
              await FirebaseService.sendTokenToBackend(fcmToken, user.id);
            } else {
              FileLogger.log('   ⚠️ Cannot send FCM token - token: ${fcmToken != null}, userId: ${user.id.isNotEmpty}');
            }
          } catch (e) {
            FileLogger.log('   ❌ Error in FCM token send flow: $e');
            // Don't fail token loading if FCM token send fails
          }
        } catch (e) {
          // If we can't restore user data, clear tokens
          await logout();
        }
      } else {
        FileLogger.log('   ⚠️ No stored tokens found - User is NOT logged in');
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          user: null,
        );
      }
      FileLogger.log('========== loadStoredTokens COMPLETE ==========');
    } catch (e) {
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
      ref.read(accessTokenProvider.notifier).state = accessToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        ref.read(refreshTokenProvider.notifier).state = refreshToken;
      }
      
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'access_token', value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: refreshToken);
      }
      
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
          
          final user = UserEntity(
            id: tokenPayload['sub']?.toString() ?? tokenPayload['id']?.toString() ?? '',
            name: tokenPayload['name']?.toString() ?? tokenPayload['username']?.toString() ?? '',
            role: tokenPayload['role']?.toString() ?? '',
            isToCustomer: tokenPayload['isToCustomer'] ?? false,
            email: tokenPayload['email']?.toString() ?? '',
            phone: tokenPayload['phone']?.toString() ?? '',
            address: tokenPayload['address']?.toString() ?? '',
            supplierId: supplierId,
          );
          
          await storage.write(key: 'user_data', value: jsonEncode({
            'id': user.id,
            'name': user.name,
            'role': user.role,
            'isToCustomer': user.isToCustomer,
            'email': user.email,
            'phone': user.phone,
            'address': user.address,
            'supplierId': user.supplierId,
          }));
          
          state = state.copyWith(
            isInitialized: true,
            user: user,
          );
          
          // Send FCM token to backend after WebView login
          FileLogger.log('   🌐 WebView login - Preparing to send FCM token');
          try {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            FileLogger.log('   FCM token retrieved: ${fcmToken != null}');
            FileLogger.log('   User ID: ${user.id}');
            
            if (fcmToken != null && user.id.isNotEmpty) {
              FileLogger.log('   ✅ Calling sendTokenToBackend...');
              await FirebaseService.sendTokenToBackend(fcmToken, user.id);
            } else {
              FileLogger.log('   ⚠️ Cannot send FCM token - token: ${fcmToken != null}, userId: ${user.id.isNotEmpty}');
            }
          } catch (e) {
            FileLogger.log('   ❌ Error in FCM token send flow: $e');
            // Don't fail sync if FCM token send fails
          }
        } else {
          state = state.copyWith(
            isInitialized: true,
            user: null,
          );
        }
      } catch (e) {
        state = state.copyWith(
          isInitialized: true,
          user: null,
        );
      }
    } catch (e) {
      // Ignore sync errors
    }
  }
}
