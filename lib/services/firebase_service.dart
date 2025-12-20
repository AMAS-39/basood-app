import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/api_endpoints.dart';
import 'notification_service.dart';
import '../core/utils/file_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FileLogger.init(); // Initialize logger in background handler
  await FileLogger.log('');
  await FileLogger.log('🔥🔥🔥 ========== BACKGROUND NOTIFICATION RECEIVED FROM FIREBASE ========== 🔥🔥🔥');
  await FileLogger.log('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
  await FileLogger.log('   Message ID: ${message.messageId ?? "N/A"}');
  await FileLogger.log('   Title: ${message.notification?.title ?? "N/A"}');
  await FileLogger.log('   Body: ${message.notification?.body ?? "N/A"}');
  await FileLogger.log('   Has notification object: ${message.notification != null}');
  await FileLogger.log('   Notification object: ${message.notification}');
  await FileLogger.log('   Data payload: ${message.data}');
  await FileLogger.log('   Sent time: ${message.sentTime}');
  await FileLogger.log('   Message type: ${message.messageType}');
  await FileLogger.log('   Collapse key: ${message.collapseKey}');
  await FileLogger.log('   From: ${message.from}');
  await FileLogger.log('   Full message object: ${message.toString()}');
  
  try {
    if (Firebase.apps.isEmpty) {
      await FileLogger.log('   Firebase not initialized, initializing now...');
      await Firebase.initializeApp();
      await FileLogger.log('   ✅ Firebase initialized in background handler');
    }
    
    await FileLogger.log('   Initializing notification service...');
    await NotificationService.instance.init();
    await FileLogger.log('   ✅ Notification service initialized');
    
    if (message.notification == null) {
      await FileLogger.log('⚠️ WARNING: message.notification is NULL in background handler');
      await FileLogger.log('   Background data-only messages should be handled by system automatically');
    } else {
      await FileLogger.log('   Calling showRemoteMessage...');
      await NotificationService.instance.showRemoteMessage(message);
      await FileLogger.log('✅ Background notification handled successfully: ${message.notification?.title}');
    }
  } catch (e, stackTrace) {
    await FileLogger.log('❌ Error in background notification handler: $e');
    await FileLogger.log('   Stack trace: $stackTrace');
    // Don't rethrow - background handler errors should not crash the app
  }
  await FileLogger.log('========== END BACKGROUND NOTIFICATION ==========');
  await FileLogger.log('');
}

class FirebaseService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static Dio? _dio; // Store Dio instance
  static const _storage = FlutterSecureStorage();
  
  // In-memory cache to prevent duplicates within same session
  static String? _lastSentToken;
  static String? _lastSentUserId;
  
  // Storage key pattern for persistence
  static String _fcmTokenKey(String userId) => 'fcm_token_sent_$userId';

  // Call this method to set Dio instance (from Riverpod)
  static void setDio(Dio dio) {
    _dio = dio;
  }
  
  // Check if FCM token was already sent for this user (persisted check)
  static Future<bool> _hasTokenBeenSent(String token, String userId) async {
    try {
      // Check in-memory cache first (fast)
      if (_lastSentToken == token && _lastSentUserId == userId) {
        return true;
      }
      
      // Check persistent storage (survives app restarts)
      final storedToken = await _storage.read(key: _fcmTokenKey(userId));
      if (storedToken == token) {
        // Update in-memory cache
        _lastSentToken = token;
        _lastSentUserId = userId;
        return true;
      }
      
      return false;
    } catch (e) {
      FileLogger.log('⚠️ Error checking FCM token persistence: $e');
      // Fall back to in-memory check only
      return _lastSentToken == token && _lastSentUserId == userId;
    }
  }
  
  // Mark FCM token as sent (persist to storage)
  static Future<void> _markTokenAsSent(String token, String userId) async {
    try {
      // Update in-memory cache
      _lastSentToken = token;
      _lastSentUserId = userId;
      
      // Persist to secure storage (survives app restarts)
      await _storage.write(key: _fcmTokenKey(userId), value: token);
      FileLogger.log('✅ FCM token marked as sent (persisted) for user: $userId');
    } catch (e) {
      FileLogger.log('⚠️ Error persisting FCM token sent flag: $e');
      // Still update in-memory cache even if persistence fails
    }
  }
  
  // Clear FCM token sent flag (e.g., on logout)
  static Future<void> clearTokenSentFlag(String userId) async {
    try {
      _lastSentToken = null;
      _lastSentUserId = null;
      await _storage.delete(key: _fcmTokenKey(userId));
      FileLogger.log('✅ FCM token sent flag cleared for user: $userId');
    } catch (e) {
      FileLogger.log('⚠️ Error clearing FCM token sent flag: $e');
    }
  }
  
  // Helper method to determine if an error should be retried
  // Only retry on network errors, timeouts, and 5xx server errors
  // DO NOT retry on 4xx client errors (like 400 Bad Request)
  static bool _shouldRetry(DioException e) {
    // Retry on network/timeout errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    
    // Retry on 5xx server errors
    final statusCode = e.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }
    
    // DO NOT retry on 4xx client errors (400, 401, 403, 404, etc.)
    return false;
  }

  // Helper: Validate inputs before sending
  static bool _validateInputs(String token, String userId) {
    if (_dio == null) {
      FileLogger.log('⚠️ Dio not initialized. Cannot send FCM token to backend.');
      return false;
    }
    if (userId.isEmpty) {
      FileLogger.log('⚠️ User ID is required. Cannot send FCM token to backend.');
      return false;
    }
    if (token.isEmpty) {
      FileLogger.log('⚠️ FCM token is empty. Cannot send to backend.');
      return false;
    }
    FileLogger.log('✅ Input validation passed - Token length: ${token.length}, UserId: $userId');
    return true;
  }
  
  // Helper: Check if backend response indicates "already have token"
  static bool _isAlreadyRegisteredError(DioException e) {
    if (e.response?.statusCode != 400) return false;
    
    final errorData = e.response?.data;
    if (errorData is! Map) return false;
    
    final errorTitle = errorData['title']?.toString().toLowerCase() ?? '';
    final errorMessage = errorData['message']?.toString().toLowerCase() ?? '';
    
    return errorTitle.contains('already have fcm token') ||
           errorTitle.contains('user already have fcm token') ||
           errorMessage.contains('already have fcm token');
  }
  
  // Helper: Attempt to send token once
  static Future<bool> _attemptSendToken(String token, String userId) async {
    try {
      FileLogger.log('📤 ========== ATTEMPTING TO SEND FCM TOKEN ==========');
      
      // CRITICAL CHECK: Verify Dio is initialized
      if (_dio == null) {
        FileLogger.log('   ❌ CRITICAL ERROR: Dio is NULL! Cannot send token to backend!');
        FileLogger.log('   This means FirebaseService.initialize() was not called with Dio instance.');
        FileLogger.log('   The request will NOT be sent to the backend!');
        return false;
      }
      
      FileLogger.log('   ✅ Dio instance is available');
      FileLogger.log('   Dio baseUrl: ${_dio!.options.baseUrl}');
      FileLogger.log('   📍 Endpoint path: ${BasoodEndpoints.user.registerFcmToken}');
      FileLogger.log('   📍 EXACT ENDPOINT: PUT ${BasoodEndpoints.user.registerFcmToken}');
      FileLogger.log('   📍 Full URL will be: ${_dio!.options.baseUrl}${BasoodEndpoints.user.registerFcmToken}');
      FileLogger.log('   Method: PUT');
      FileLogger.log('   UserId: $userId');
      FileLogger.log('   Token length: ${token.length} characters');
      FileLogger.log('   Full FCM Token (EXACT, NO TRIMMING): $token');
      
      // Verify token is valid (NO TRIMMING - send exactly as received)
      if (token.isEmpty) {
        FileLogger.log('   ❌ ERROR: Token is empty!');
        return false;
      }
      if (token.length < 100) {
        FileLogger.log('   ⚠️ WARNING: Token seems too short (${token.length} chars). Expected ~140-160 chars.');
      }
      
      // CRITICAL: Send token EXACTLY as received - NO TRIMMING, NO MODIFICATION
      // The token parameter is already the exact token from Firebase - use it directly
      final payload = {
        'FcmToken': token, // EXACT token - NO .trim(), NO modification
        'userId': userId,
      };
      
      // Get access token from secure storage for Authorization header
      String? accessToken;
      try {
        accessToken = await _storage.read(key: 'access_token');
        FileLogger.log('   🔑 Access token retrieved from storage: ${accessToken != null ? "YES (${accessToken.length} chars)" : "NO"}');
        if (accessToken != null && accessToken.isNotEmpty) {
          FileLogger.log('   🔑 Access token (first 20 chars): ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
        }
      } catch (e) {
        FileLogger.log('   ⚠️ Error reading access token from storage: $e');
      }
      
      // Prepare headers - explicitly add Authorization header
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };
      
      // Add Authorization header if access token is available
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
        FileLogger.log('   ✅ Authorization header will be added: Bearer [token]');
      } else {
        FileLogger.log('   ⚠️ WARNING: Access token is NULL or empty - Authorization header will NOT be added!');
        FileLogger.log('   ⚠️ Backend may reject this request if authentication is required!');
      }
      
      // Log the exact payload being sent (BEFORE API call)
      FileLogger.log('   📦 ========== EXACT PAYLOAD BEING SENT TO BACKEND ==========');
      FileLogger.log('      Original token parameter: $token');
      FileLogger.log('      Token length: ${token.length} characters');
      FileLogger.log('      Payload FcmToken field: ${payload['FcmToken']}');
      FileLogger.log('      Payload FcmToken length: ${payload['FcmToken']?.toString().length ?? 0} characters');
      FileLogger.log('      Payload userId field: ${payload['userId']}');
      FileLogger.log('      Tokens match (original == payload): ${token == payload['FcmToken']}');
      FileLogger.log('      Token has leading/trailing spaces: ${token != token.trim()}');
      FileLogger.log('      Full payload JSON: ${payload.toString()}');
      FileLogger.log('   📋 Request headers: $headers');
      FileLogger.log('   🚀 NOW SENDING PUT REQUEST TO BACKEND...');
      
      final response = await _dio!.put(
        BasoodEndpoints.user.registerFcmToken,
        data: payload,
        options: Options(
          headers: headers,
        ),
      );
      
      FileLogger.log('   ✅ API CALL COMPLETED SUCCESSFULLY');
      FileLogger.log('   Response status code: ${response.statusCode}');
      FileLogger.log('   Response data: ${response.data}');
      FileLogger.log('   Response headers: ${response.headers}');
      FileLogger.log('   🔍 POST-SEND VERIFICATION:');
      FileLogger.log('      Token that was sent in FcmToken field: ${payload['FcmToken']}');
      FileLogger.log('      Token sent length: ${payload['FcmToken']?.toString().length ?? 0}');
      FileLogger.log('      Original token parameter: $token');
      FileLogger.log('      Original token length: ${token.length}');
      FileLogger.log('      Tokens match (sent vs original): ${payload['FcmToken'] == token}');
      FileLogger.log('      This MUST match the token from logs above - EXACT SAME VALUE');
      FileLogger.log('   ✅ REQUEST WAS SENT TO BACKEND ENDPOINT: PUT ${_dio!.options.baseUrl}${BasoodEndpoints.user.registerFcmToken}');
      FileLogger.log('   ✅ CONFIRMED: Endpoint path is exactly: ${BasoodEndpoints.user.registerFcmToken}');
      
      // Success (200-299)
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        FileLogger.log('✅ FCM Token sent successfully for user: $userId');
        await _markTokenAsSent(token, userId);
        return true;
      }
      
      // Non-success response (shouldn't happen with Dio, but handle it)
      FileLogger.log('⚠️ Backend returned non-success status: ${response.statusCode}');
      return false;
      
    } on DioException catch (e) {
      // Handle "already have token" as success
      if (_isAlreadyRegisteredError(e)) {
        FileLogger.log('ℹ️ FCM token already registered — treating as success');
        FileLogger.log('   Token that was sent: $token');
        FileLogger.log('   Token length: ${token.length}');
        await _markTokenAsSent(token, userId);
        return true;
      }
      
      // Log error details
      FileLogger.log('❌ FAILED TO SEND FCM TOKEN TO BACKEND');
      FileLogger.log('   DioException type: ${e.type}');
      FileLogger.log('   Request URL: ${e.requestOptions.uri}');
      FileLogger.log('   Request method: ${e.requestOptions.method}');
      FileLogger.log('   Request data sent: ${e.requestOptions.data}');
      FileLogger.log('   Status code: ${e.response?.statusCode}');
      FileLogger.log('   Error message: ${e.message}');
      FileLogger.log('   Token that was attempted: $token');
      FileLogger.log('   Token length: ${token.length}');
      if (e.response?.data != null) {
        FileLogger.log('   Error response data: ${e.response?.data}');
      }
      if (e.response?.headers != null) {
        FileLogger.log('   Response headers: ${e.response?.headers}');
      }
      FileLogger.log('   Stack trace: ${e.stackTrace}');
      
      // Re-throw to let retry logic handle it
      rethrow;
    } catch (e, stackTrace) {
      FileLogger.log('❌ Unexpected error sending FCM token: $e');
      FileLogger.log('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Method to send FCM token to backend with user ID
  // Retries up to 3 times ONLY on retryable errors (network, 5xx)
  // Treats "already have fcm token" (400) as success
  static Future<bool> sendTokenToBackend(String token, String userId, {int retries = 3}) async {
    // Log token at entry point
    FileLogger.log('📤 ========== sendTokenToBackend CALLED ==========');
    FileLogger.log('   Token parameter received: $token');
    FileLogger.log('   Token parameter length: ${token.length}');
    FileLogger.log('   Token parameter (first 50 chars): ${token.length > 50 ? token.substring(0, 50) : token}...');
    FileLogger.log('   Token parameter (last 50 chars): ...${token.length > 50 ? token.substring(token.length - 50) : token}');
    FileLogger.log('   UserId: $userId');
    
    // 1. Validate inputs
    if (!_validateInputs(token, userId)) {
      return false;
    }
    
    // 2. Check for duplicate send (in-memory + persistent)
    FileLogger.log('🔍 Checking if FCM token already sent for user: $userId');
    if (await _hasTokenBeenSent(token, userId)) {
      FileLogger.log('⏭️ FCM token already sent for user $userId — skipping duplicate');
      return true;
    }
    FileLogger.log('✅ Token not sent yet, proceeding to send...');
    
    // 3. Try to send with retry logic
    int attempt = 0;
    while (attempt < retries) {
      attempt++;
      FileLogger.log('🔄 Send attempt $attempt/$retries');
      
      try {
        final success = await _attemptSendToken(token, userId);
        if (success) {
          FileLogger.log('✅ FCM token send completed successfully');
          return true;
        }
        
        // If attemptSendToken returns false (non-success response), don't retry
        FileLogger.log('⚠️ Send returned false, not retrying');
        return false;
        
      } on DioException catch (e) {
        // Check if we should retry this error
        if (!_shouldRetry(e)) {
          FileLogger.log('⚠️ Non-retryable error (${e.response?.statusCode}) — stopping');
          return false;
        }
        
        // Retryable error - attempt again
        if (attempt < retries) {
          FileLogger.log('   ⏳ Retrying in $attempt second(s)... (attempt ${attempt + 1}/$retries)');
          await Future.delayed(Duration(seconds: attempt));
        } else {
          FileLogger.log('❌ All retry attempts exhausted');
          return false;
        }
      } catch (e, stackTrace) {
        // Non-DioException errors - retry once more
        FileLogger.log('❌ Unexpected error in send attempt: $e');
        FileLogger.log('   Stack trace: $stackTrace');
        if (attempt < retries) {
          FileLogger.log('   ⏳ Retrying after unexpected error in $attempt second(s)...');
          await Future.delayed(Duration(seconds: attempt));
        } else {
          FileLogger.log('❌ Failed after $retries attempts');
          return false;
        }
      }
    }
    
    FileLogger.log('❌ FCM token send failed after all attempts');
    return false;
  }

  static Future<void> initialize({Dio? dio}) async {
    FileLogger.log('🔥 ========== INITIALIZING FIREBASE SERVICE ==========');
    try {
      if (dio != null) {
        setDio(dio);
        FileLogger.log('✅ Dio instance set');
        FileLogger.log('   Dio baseUrl: ${dio.options.baseUrl}');
        FileLogger.log('   Dio interceptors count: ${dio.interceptors.length}');
      } else {
        FileLogger.log('❌ CRITICAL ERROR: Dio instance is NULL - FCM token sending will FAIL!');
        FileLogger.log('   This means sendTokenToBackend will not work!');
      }

      // Initialize notification service (already initialized in main, but safe to call again)
      FileLogger.log('📦 Initializing notification service...');
      await NotificationService.instance.init();
      FileLogger.log('✅ Notification service initialized');

      // Request notification permissions
      FileLogger.log('🔔 Requesting notification permissions...');
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FileLogger.log('   Permission status: ${settings.authorizationStatus}');
      FileLogger.log('   Alert: ${settings.alert}');
      FileLogger.log('   Badge: ${settings.badge}');
      FileLogger.log('   Sound: ${settings.sound}');

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FileLogger.log('✅ Foreground notification presentation options set');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        FileLogger.log('❌ Notification permission denied');
      } else {
        FileLogger.log('✅ Notification permission status: ${settings.authorizationStatus}');
      }

      // Get FCM token asynchronously (will be sent to backend when user logs in)
      // Don't await to avoid blocking initialization
      FileLogger.log('🔑 Requesting FCM token...');
      _fcm.getToken().then((token) async {
        if (token != null) {
          FileLogger.log('✅ FCM Token received (FULL TOKEN): $token');
          FileLogger.log('   Token length: ${token.length} characters');
          FileLogger.log('   Full token will be sent to backend after login');
        } else {
          FileLogger.log('⚠️ FCM token is null');
        }
      }).catchError((e) async {
        FileLogger.log('❌ Error getting FCM token: $e');
        // Don't throw - app should work even if token retrieval fails
      });

      // Listen for token refresh (will be sent to backend if user is logged in)
      _fcm.onTokenRefresh.listen((newToken) async {
        try {
          FileLogger.log('🔄 ========== FCM TOKEN REFRESHED ==========');
          FileLogger.log('   New token (FULL TOKEN): $newToken');
          FileLogger.log('   Token length: ${newToken.length} characters');
          FileLogger.log('   Token will be sent by auth_controller if user is logged in');
        } catch (e) {
          FileLogger.log('⚠️ Error handling token refresh: $e');
          // Don't throw - token refresh should not crash the app
        }
      });
      FileLogger.log('✅ Token refresh listener registered');
    } catch (e, stackTrace) {
      FileLogger.log('❌ Error initializing Firebase service: $e');
      FileLogger.log('   Stack trace: $stackTrace');
      // Don't throw - app should work even if Firebase initialization fails
    }

    // Handle foreground notifications (app is open)
    FileLogger.log('📡 Setting up foreground notification listener...');
    FileLogger.log('   ✅ Foreground listener is ACTIVE and waiting for notifications');
    FirebaseMessaging.onMessage.listen((message) async {
      FileLogger.log('');
      FileLogger.log('🔥🔥🔥 ========== FOREGROUND NOTIFICATION RECEIVED FROM FIREBASE ========== 🔥🔥🔥');
      FileLogger.log('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      FileLogger.log('   Message ID: ${message.messageId ?? "N/A"}');
      FileLogger.log('   Title: ${message.notification?.title ?? "N/A"}');
      FileLogger.log('   Body: ${message.notification?.body ?? "N/A"}');
      FileLogger.log('   Has notification object: ${message.notification != null}');
      FileLogger.log('   Notification object: ${message.notification}');
      FileLogger.log('   Data payload: ${message.data}');
      FileLogger.log('   Sent time: ${message.sentTime}');
      FileLogger.log('   Message type: ${message.messageType}');
      FileLogger.log('   Collapse key: ${message.collapseKey}');
      FileLogger.log('   From: ${message.from}');
      FileLogger.log('   Full message object: ${message.toString()}');
      
      if (message.notification == null) {
        FileLogger.log('⚠️ WARNING: message.notification is NULL - this is a data-only message');
        FileLogger.log('   Foreground data-only messages are NOT auto-displayed by Firebase');
        FileLogger.log('   Skipping notification display');
      } else {
        FileLogger.log('✅ Notification payload is present - will attempt to display');
        try {
          FileLogger.log('   Calling showRemoteMessage...');
          await NotificationService.instance.showRemoteMessage(message);
          FileLogger.log('✅ Foreground notification displayed successfully');
        } catch (e, stackTrace) {
          FileLogger.log('❌ Error showing foreground notification: $e');
          FileLogger.log('   Stack trace: $stackTrace');
        }
      }
      FileLogger.log('========== END FOREGROUND NOTIFICATION ==========');
      FileLogger.log('');
    });

    // Handle notifications when app is opened from background
    FileLogger.log('📡 Setting up background notification opened listener...');
    FileLogger.log('   ✅ Background opened listener is ACTIVE');
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      FileLogger.log('');
      FileLogger.log('🔥🔥🔥 ========== NOTIFICATION OPENED (FROM BACKGROUND) ========== 🔥🔥🔥');
      FileLogger.log('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      FileLogger.log('   Message ID: ${message.messageId ?? "N/A"}');
      FileLogger.log('   Title: ${message.notification?.title ?? "N/A"}');
      FileLogger.log('   Body: ${message.notification?.body ?? "N/A"}');
      FileLogger.log('   Data: ${message.data}');
      FileLogger.log('   Full message: ${message.toString()}');
      // Trigger app refresh/navigation if needed
      NotificationService.instance.handleNotificationTap(message);
      FileLogger.log('========== END BACKGROUND OPENED NOTIFICATION ==========');
      FileLogger.log('');
    });

    // Handle notifications when app is opened from terminated state
    FileLogger.log('📡 Checking for initial notification (terminated state)...');
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      FileLogger.log('');
      FileLogger.log('🔥🔥🔥 ========== NOTIFICATION OPENED (FROM TERMINATED) ========== 🔥🔥🔥');
      FileLogger.log('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      FileLogger.log('   Message ID: ${initialMessage.messageId ?? "N/A"}');
      FileLogger.log('   Title: ${initialMessage.notification?.title ?? "N/A"}');
      FileLogger.log('   Body: ${initialMessage.notification?.body ?? "N/A"}');
      FileLogger.log('   Data: ${initialMessage.data}');
      FileLogger.log('   Full message: ${initialMessage.toString()}');
      // Trigger app refresh/navigation if needed
      NotificationService.instance.handleNotificationTap(initialMessage);
      FileLogger.log('========== END TERMINATED NOTIFICATION ==========');
      FileLogger.log('');
    } else {
      FileLogger.log('   ✅ No initial notification found (app was not opened from notification)');
    }
    
    FileLogger.log('');
    FileLogger.log('✅ ========== FIREBASE SERVICE INITIALIZATION COMPLETED ==========');
    FileLogger.log('   ✅ Foreground notification listener: ACTIVE');
    FileLogger.log('   ✅ Background notification opened listener: ACTIVE');
    FileLogger.log('   ✅ Background message handler: REGISTERED');
    FileLogger.log('   ✅ Token refresh listener: ACTIVE');
    FileLogger.log('   ✅ Notification service: INITIALIZED');
    FileLogger.log('   ✅ Notification channel: basood_notifications');
    FileLogger.log('');
    FileLogger.log('📱 App is now ready to receive notifications from Firebase');
    FileLogger.log('   If a notification is sent, you will see:');
    FileLogger.log('   - "🔥🔥🔥 FOREGROUND NOTIFICATION RECEIVED FROM FIREBASE 🔥🔥🔥" (if app is open)');
    FileLogger.log('   - "🔥🔥🔥 BACKGROUND NOTIFICATION RECEIVED FROM FIREBASE 🔥🔥🔥" (if app is closed)');
    FileLogger.log('');
  }
}
