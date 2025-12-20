import '../entities/user_entity.dart';
import '../value_objects/token_pair.dart';

abstract class AuthRepository {
  Future<(UserEntity, TokenPair)> loginMobile({
    required String username,
    required String password,
  });
  Future<TokenPair?> refreshToken();
  Future<void> revokeToken();
}
