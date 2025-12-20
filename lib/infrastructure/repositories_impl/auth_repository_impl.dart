import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/token_pair.dart';
import '../datasources/auth_remote_ds.dart';
import '../dtos/auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDS ds;
  AuthRepositoryImpl(this.ds);

  @override
  Future<(UserEntity, TokenPair)> loginMobile({
    required String username,
    required String password,
  }) async {
    try {
          final request = LoginRequestDto(
            username: username,
            password: password,
          );
      final response = await ds.loginMobile(request);
      final dto = LoginResponseDto.fromJson(response.data);
      
      final user = UserEntity(
        id: dto.id,
        name: dto.name,
        role: dto.role,
        isToCustomer: dto.isToCustomer,
        email: dto.email,
        phone: dto.phone,
        address: dto.address,
        supplierId: dto.supplierId,
      );
      
      final tokens = TokenPair(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
      );
      
      return (user, tokens);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<TokenPair?> refreshToken() async {
    try {
      final response = await ds.refreshToken();
      final dto = RefreshTokenResponseDto.fromJson(response.data);
      
      return TokenPair(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> revokeToken() async {
    try {
      await ds.revokeToken();
    } catch (e) {
      // Ignore errors on logout
    }
  }
}
