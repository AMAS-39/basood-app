import 'package:dio/dio.dart';
import '../../core/config/api_endpoints.dart';
import '../dtos/auth_dtos.dart';

class AuthRemoteDS {
  final Dio dio;
  AuthRemoteDS(this.dio);

  Future<Response> loginMobile(LoginRequestDto request) =>
      dio.post(BasoodEndpoints.user.loginMobile, data: request.toJson());

  Future<Response> refreshToken() => dio.post(BasoodEndpoints.user.refreshToken);

  Future<Response> revokeToken() => dio.post(BasoodEndpoints.user.revokeToken);
}
