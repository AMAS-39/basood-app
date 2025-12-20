import 'package:dio/dio.dart';
import '../config/env.dart';

class DioClient {
  Dio create({
    required Interceptor authInterceptor,
    required Interceptor refreshInterceptor,
  }) {
        final dio = Dio(BaseOptions(
          baseUrl: Env.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

    dio.interceptors.addAll([
      refreshInterceptor, // handles 401 → refresh
      authInterceptor,    // adds Authorization header
      LogInterceptor(responseBody: true, requestBody: true),
    ]);
    return dio;
  }
}
