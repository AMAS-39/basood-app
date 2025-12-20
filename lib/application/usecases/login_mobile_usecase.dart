import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/token_pair.dart';

class LoginMobileUC {
  final AuthRepository repo;
  LoginMobileUC(this.repo);

  Future<(UserEntity, TokenPair)> call({
    required String username,
    required String password,
  }) => repo.loginMobile(username: username, password: password);
}
