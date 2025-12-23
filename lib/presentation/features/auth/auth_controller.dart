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
    // Listen for token refresh and send to backend if user is logged in
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      FileLogger.log('🔄 ========== FCM TOKEN REFRESH (from AuthController) ==========');
      FileLogger.log('   New token (FULL TOKEN): $newToken');
      FileLogger.log('   Token length: ${newToken.length} characters');
      try {
        // Only send if user is logged in
        if (state.user != null && state.user!.id.isNotEmpty) {
          FileLogger.log('   User is logged in (${state.user!.id}), sending token to backend...');
          final success = await FirebaseService.sendTokenToBackend(
            newToken,
            state.user!.id,
          );
          if (success) {
            FileLogger.log('✅ Refreshed FCM token sent to backend for user: ${state.user!.id}');
          } else {
            FileLogger.log('⚠️ Failed to send refreshed FCM token to backend');
          }
        } else {
          FileLogger.log('⏭️ User not logged in, skipping token refresh send');
        }
      } catch (e) {
        FileLogger.log('⚠️ Error handling token refresh: $e');
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
      
      // Send FCM token to backend after successful login with user ID
      FileLogger.log('🔐 ========== LOGIN SUCCESSFUL ==========');
      FileLogger.log('   User ID: ${user.id}');
      FileLogger.log('   User name: ${user.name}');
      try {
        FileLogger.log('   Getting FCM token...');
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && user.id.isNotEmpty) {
          FileLogger.log('   FCM token retrieved (FULL TOKEN): $fcmToken');
          FileLogger.log('   Token length: ${fcmToken.length} characters');
          FileLogger.log('   Sending to backend...');
          final success = await FirebaseService.sendTokenToBackend(fcmToken, user.id);
          if (success) {
            FileLogger.log('✅ FCM token sent to backend after login for user: ${user.id}');
          } else {
            FileLogger.log('⚠️ Failed to send FCM token to backend after login');
          }
        } else {
          FileLogger.log('⚠️ FCM token is null or user ID is empty - token: ${fcmToken != null}, user ID: ${user.id.isNotEmpty}');
        }
      } catch (e) {
        FileLogger.log('⚠️ Error sending FCM token after login: $e');
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
    FileLogger.log('🔐 ========== LOADING STORED TOKENS ==========');
    state = state.copyWith(isLoading: true);
    
    try {
      final storage = ref.read(secureStorageProvider);
      FileLogger.log('   📦 Reading tokens from secure storage...');
      
      final accessToken = await storage.read(key: 'access_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      final userJson = await storage.read(key: 'user_data');
      
      FileLogger.log('   Access token found: ${accessToken != null ? "YES (${accessToken.length} chars)" : "NO"}');
      FileLogger.log('   Refresh token found: ${refreshToken != null ? "YES (${refreshToken.length} chars)" : "NO"}');
      FileLogger.log('   User data found: ${userJson != null ? "YES" : "NO"}');
      
      if (accessToken != null && refreshToken != null && userJson != null) {
        FileLogger.log('   ✅ All tokens found - user is logged in');
        ref.read(accessTokenProvider.notifier).state = accessToken;
        ref.read(refreshTokenProvider.notifier).state = refreshToken;
        FileLogger.log('   ✅ Tokens loaded into provider state');
        
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
          
          FileLogger.log('   👤 User loaded:');
          FileLogger.log('      User ID: ${user.id}');
          FileLogger.log('      User name: ${user.name}');
          
          state = state.copyWith(
            isLoading: false,
            isInitialized: true,
            user: user,
          );
          
          // Send FCM token to backend with user ID if user is already logged in
          FileLogger.log('   📤 Attempting to send FCM token to backend...');
          try {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            FileLogger.log('   🔑 FCM token retrieved: ${fcmToken != null ? "YES (${fcmToken.length} chars)" : "NO"}');
            
            if (fcmToken != null && user.id.isNotEmpty) {
              FileLogger.log('   📤 Calling sendTokenToBackend...');
              FileLogger.log('      FCM Token (FULL): $fcmToken');
              FileLogger.log('      Token length: ${fcmToken.length} characters');
              FileLogger.log('      User ID: ${user.id}');
              
              final success = await FirebaseService.sendTokenToBackend(fcmToken, user.id);
              if (success) {
                FileLogger.log('✅ FCM token sent to backend after loading stored tokens for user: ${user.id}');
              } else {
                FileLogger.log('⚠️ Failed to send FCM token to backend after loading stored tokens');
              }
            } else {
              FileLogger.log('⚠️ Cannot send FCM token: fcmToken=${fcmToken != null}, userId=${user.id.isNotEmpty}');
            }
          } catch (e, stackTrace) {
            FileLogger.log('❌ Error sending FCM token after loading stored tokens: $e');
            FileLogger.log('   Stack trace: $stackTrace');
            // Don't fail token loading if FCM token send fails
          }
        } catch (e, stackTrace) {
          FileLogger.log('❌ Error decoding user data: $e');
          FileLogger.log('   Stack trace: $stackTrace');
          // If we can't restore user data, clear tokens
          await logout();
        }
      } else {
        FileLogger.log('   ⚠️ No stored tokens found - user is not logged in');
        // No stored tokens, user is not logged in
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          user: null,
        );
      }
    } catch (e, stackTrace) {
      FileLogger.log('❌ Error loading tokens: $e');
      FileLogger.log('   Stack trace: $stackTrace');
      // Error loading tokens, clear everything
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        user: null,
        error: e.toString(),
      );
    }
    FileLogger.log('========== END LOADING STORED TOKENS ==========');
  }

  /// Sync tokens from WebView login (when user logs in via web page)
  Future<void> syncTokensFromWebView({
    required String accessToken,
    String? refreshToken,
  }) async {
    FileLogger.log('🌐 ========== SYNC TOKENS FROM WEBVIEW ==========');
    FileLogger.log('   Access token received: ${accessToken.isNotEmpty ? "YES (${accessToken.length} chars)" : "NO"}');
    FileLogger.log('   Refresh token received: ${refreshToken != null && refreshToken.isNotEmpty ? "YES (${refreshToken.length} chars)" : "NO"}');
    
    try {
      // Update provider state
      ref.read(accessTokenProvider.notifier).state = accessToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        ref.read(refreshTokenProvider.notifier).state = refreshToken;
      }
      FileLogger.log('   ✅ Tokens stored in provider state');
      
      // Store in secure storage
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'access_token', value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: refreshToken);
      }
      FileLogger.log('   ✅ Tokens stored in secure storage');
      
      // Try to extract user info from token
      try {
        FileLogger.log('   🔍 Decoding user info from token...');
        final tokenPayload = JwtUtils.decodeToken(accessToken);
        if (tokenPayload != null) {
          FileLogger.log('   ✅ Token decoded successfully');
          
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
            id: tokenPayload['sub']?.toString() ?? tokenPayload['id']?.toString() ?? '',
            name: tokenPayload['name']?.toString() ?? tokenPayload['username']?.toString() ?? '',
            role: tokenPayload['role']?.toString() ?? '',
            isToCustomer: tokenPayload['isToCustomer'] ?? false,
            email: tokenPayload['email']?.toString() ?? '',
            phone: tokenPayload['phone']?.toString() ?? '',
            address: tokenPayload['address']?.toString() ?? '',
            supplierId: supplierId,
          );
          
          FileLogger.log('   👤 User extracted from token:');
          FileLogger.log('      User ID: ${user.id}');
          FileLogger.log('      User name: ${user.name}');
          FileLogger.log('      User role: ${user.role}');
          
          // Store user data
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
          FileLogger.log('   ✅ User data stored');
          
          // Update state with user
          state = state.copyWith(
            isInitialized: true,
            user: user,
          );
          FileLogger.log('   ✅ Auth state updated with user');
          
          // Send FCM token to backend with user ID after WebView login
          FileLogger.log('   📤 Attempting to send FCM token to backend...');
          try {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            FileLogger.log('   🔑 FCM token retrieved: ${fcmToken != null ? "YES (${fcmToken.length} chars)" : "NO"}');
            
            if (fcmToken != null && user.id.isNotEmpty) {
              FileLogger.log('   📤 Calling sendTokenToBackend...');
              FileLogger.log('      FCM Token: $fcmToken');
              FileLogger.log('      User ID: ${user.id}');
              
              final success = await FirebaseService.sendTokenToBackend(fcmToken, user.id);
              if (success) {
                FileLogger.log('✅ FCM token sent to backend after WebView login for user: ${user.id}');
              } else {
                FileLogger.log('⚠️ Failed to send FCM token to backend after WebView login');
              }
            } else {
              FileLogger.log('⚠️ Cannot send FCM token: fcmToken=${fcmToken != null}, userId=${user.id.isNotEmpty}');
            }
          } catch (e, stackTrace) {
            FileLogger.log('❌ Error sending FCM token after WebView login: $e');
            FileLogger.log('   Stack trace: $stackTrace');
            // Don't fail sync if FCM token send fails
          }
        } else {
          FileLogger.log('⚠️ Could not decode token payload - token is null');
          // Can't decode token, but tokens are stored
          // User will be loaded on next app restart if backend provides user info
          state = state.copyWith(
            isInitialized: true,
            user: null,
          );
        }
      } catch (e, stackTrace) {
        // Can't decode token, but tokens are stored
        FileLogger.log('❌ Error decoding user info from token: $e');
        FileLogger.log('   Stack trace: $stackTrace');
        state = state.copyWith(
          isInitialized: true,
          user: null,
        );
      }
      
      FileLogger.log('✅ Tokens synced from WebView successfully');
    } catch (e, stackTrace) {
      FileLogger.log('❌ Error syncing tokens from WebView: $e');
      FileLogger.log('   Stack trace: $stackTrace');
    }
    FileLogger.log('========== END SYNC TOKENS FROM WEBVIEW ==========');
  }
}
