import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../core/config/api_endpoints.dart';
import 'notification_service.dart';
import '../core/utils/file_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.instance.init();

  if (message.notification != null) {
    await NotificationService.instance.showRemoteMessage(message);
  }
}

class FirebaseService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static Dio? _dio;
  static const _storage = FlutterSecureStorage();

  static String? _lastSentToken;
  static String? _lastSentUserId;

  static String _fcmTokenKey(String userId) => 'fcm_token_sent_$userId';

  static void setDio(Dio dio) {
    _dio = dio;
  }

  /// ✅ CRITICAL FIX — REAL FCM TOKEN CHECK
  static bool _isValidFcmToken(String token) {
    return token.length > 120 && token.contains(':');
  }

  static Future<void> clearTokenSentFlag(String userId) async {
    _lastSentToken = null;
    _lastSentUserId = null;
    await _storage.delete(key: _fcmTokenKey(userId));
  }

  static Future<bool> _hasTokenBeenSent(String token, String userId) async {
    if (_lastSentToken == token && _lastSentUserId == userId) return true;
    final stored = await _storage.read(key: _fcmTokenKey(userId));
    return stored == token;
  }

  static Future<void> _markTokenAsSent(String token, String userId) async {
    _lastSentToken = token;
    _lastSentUserId = userId;
    await _storage.write(key: _fcmTokenKey(userId), value: token);
  }

  static Future<bool> sendTokenToBackend(
      String token, String userId) async {
    FileLogger.log('🔍 ========== sendTokenToBackend CALLED ==========');
    FileLogger.log('   UserId: $userId');
    FileLogger.log('   Token length: ${token.length}');
    FileLogger.log('   Dio initialized: ${_dio != null}');
    
    if (_dio == null) {
      FileLogger.log('❌ Cannot send FCM token - Dio is null (not initialized)');
      return false;
    }

    if (!_isValidFcmToken(token)) {
      FileLogger.log('❌ Cannot send FCM token - Invalid token');
      FileLogger.log('   Token length: ${token.length} (needs > 120)');
      FileLogger.log('   Contains ":": ${token.contains(':')}');
      return false;
    }

    final alreadySent = await _hasTokenBeenSent(token, userId);
    if (alreadySent) {
      FileLogger.log('⏭️ FCM token already sent for this user - skipping');
      return true;
    }

    final accessToken = await _storage.read(key: 'access_token');
    FileLogger.log('   Access token available: ${accessToken != null}');
    
    final endpoint = BasoodEndpoints.user.registerFcmToken;
    final baseUrl = _dio!.options.baseUrl;
    final fullUrl = '$baseUrl$endpoint';
    
    FileLogger.log('📤 Sending FCM token to backend: $fullUrl');
    FileLogger.log('   Method: PUT');
    FileLogger.log('   UserId: $userId');
    FileLogger.log('   FCM Token: $token');
    FileLogger.log('   Payload: {FcmToken: $token, userId: $userId}');
    
    try {
      final response = await _dio!.put(
        endpoint,
        data: {
          'FcmToken': token,
          'userId': userId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        FileLogger.log('✅ FCM token sent successfully to backend: $fullUrl');
        FileLogger.log('   Response status: ${response.statusCode}');
        FileLogger.log('   Response data: ${response.data}');
        await _markTokenAsSent(token, userId);
        FileLogger.log('========== FCM TOKEN SEND COMPLETE ==========');
        return true;
      }

      FileLogger.log('❌ FCM token send failed - Status: ${response.statusCode}');
      FileLogger.log('   Response data: ${response.data}');
      FileLogger.log('========== FCM TOKEN SEND FAILED ==========');
      return false;
    } catch (e) {
      if (e is DioException) {
        FileLogger.log('❌ FCM token send error (DioException):');
        FileLogger.log('   Type: ${e.type}');
        FileLogger.log('   Status: ${e.response?.statusCode}');
        FileLogger.log('   Message: ${e.message}');
        FileLogger.log('   Response data: ${e.response?.data}');
      } else {
        FileLogger.log('❌ FCM token send error: $e');
      }
      FileLogger.log('========== FCM TOKEN SEND ERROR ==========');
      return false;
    }
  }

  static Future<void> initialize({required Dio dio}) async {
    FileLogger.log('🔥 Initializing FirebaseService...');
    setDio(dio);
    FileLogger.log('   Dio instance set: ${_dio != null}');
    if (_dio != null) {
      FileLogger.log('   Dio baseUrl: ${_dio!.options.baseUrl}');
    }

    await NotificationService.instance.init();

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    await _fcm.getToken();

    _fcm.onTokenRefresh.listen((newToken) async {
      FileLogger.log('🔄 FCM Token refreshed');
      if (!_isValidFcmToken(newToken)) {
        FileLogger.log('   Invalid token - not sending');
        return;
      }

      // Get userId from user_data JSON (not from separate user_id key)
      final userJson = await _storage.read(key: 'user_data');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          final userId = userData['id']?.toString();
          if (userId != null && userId.isNotEmpty) {
            FileLogger.log('   UserId found in user_data: $userId');
            await clearTokenSentFlag(userId);
            await sendTokenToBackend(newToken, userId);
          } else {
            FileLogger.log('   UserId not found in user_data JSON');
          }
        } catch (e) {
          FileLogger.log('   Error parsing user_data: $e');
        }
      } else {
        FileLogger.log('   No user_data found - user not logged in');
      }
    });

    FirebaseMessaging.onMessage.listen((message) async {
      if (message.notification != null) {
        await NotificationService.instance.showRemoteMessage(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationService.instance.handleNotificationTap(message);
    });
  }
}
