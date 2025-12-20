import 'package:dio/dio.dart';

sealed class AppFailure {
  const AppFailure();
  
  factory AppFailure.fromDioException(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkFailure('Connection timeout');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 401) {
            return AuthFailure('Unauthorized');
          } else if (statusCode == 403) {
            return AuthFailure('Forbidden');
          } else if (statusCode != null && statusCode >= 500) {
            return ServerFailure('Server error', statusCode);
          } else {
            return ServerFailure('Bad response', statusCode);
          }
        case DioExceptionType.cancel:
          return NetworkFailure('Request cancelled');
        case DioExceptionType.connectionError:
          return NetworkFailure('Connection error');
        default:
          return UnknownFailure('Unknown error');
      }
    }
    return UnknownFailure(e.toString());
  }
}

class NetworkFailure extends AppFailure {
  final String message;
  const NetworkFailure(this.message);
}

class AuthFailure extends AppFailure {
  final String message;
  const AuthFailure(this.message);
}

class ValidationFailure extends AppFailure {
  final String message;
  const ValidationFailure(this.message);
}

class ServerFailure extends AppFailure {
  final String message;
  final int? statusCode;
  const ServerFailure(this.message, [this.statusCode]);
}

class UnknownFailure extends AppFailure {
  final String message;
  const UnknownFailure(this.message);
}
