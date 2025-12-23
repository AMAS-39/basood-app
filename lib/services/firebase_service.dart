import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    if (_dio == null) return false;

    if (!_isValidFcmToken(token)) {
      return false;
    }

    if (await _hasTokenBeenSent(token, userId)) {
      return true;
    }

    final accessToken = await _storage.read(key: 'access_token');
    final endpoint = BasoodEndpoints.user.registerFcmToken;
    final baseUrl = _dio!.options.baseUrl;
    final fullUrl = '$baseUrl$endpoint';
    
    FileLogger.log('📤 Sending FCM token to backend: $fullUrl');
    FileLogger.log('   Method: PUT');
    FileLogger.log('   UserId: $userId');
    FileLogger.log('   FCM Token: $token');
    
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
        await _markTokenAsSent(token, userId);
        return true;
      }

      FileLogger.log('❌ FCM token send failed - Status: ${response.statusCode}');
      return false;
    } catch (e) {
      FileLogger.log('❌ FCM token send error: $e');
      return false;
    }
  }

  static Future<void> initialize({required Dio dio}) async {
    setDio(dio);

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
      if (!_isValidFcmToken(newToken)) return;

      final userId = await _storage.read(key: 'user_id');
      if (userId != null) {
        await clearTokenSentFlag(userId);
        await sendTokenToBackend(newToken, userId);
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
