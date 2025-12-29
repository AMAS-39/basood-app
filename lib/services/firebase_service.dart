import 'package:dio/dio.dart';
import '../core/config/api_endpoints.dart';

class FirebaseService {
  static Dio? _dio;

  /// Initialize FirebaseService with Dio instance
  static void initialize({required Dio dio}) {
    _dio = dio;
  }

  /// Send FCM token to backend
  /// Requires FirebaseService to be initialized with Dio first
  static Future<void> sendTokenToBackend(String fcmToken) async {
    if (_dio == null) {
      throw Exception(
        'FirebaseService not initialized. Call FirebaseService.initialize(dio: dio) first.',
      );
    }

    try {
      await _dio!.post(
        BasoodEndpoints.user.registerFcmToken,
        data: {'fcmToken': fcmToken},
      );
    } catch (e) {
      throw Exception('Failed to send FCM token to backend: $e');
    }
  }
}
