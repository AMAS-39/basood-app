import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/token_pair.dart';

class RefreshTokenUC {
  final AuthRepository repo;
  RefreshTokenUC(this.repo);

  Future<TokenPair?> call() => repo.refreshToken();
}
