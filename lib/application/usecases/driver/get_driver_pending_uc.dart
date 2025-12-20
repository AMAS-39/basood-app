import '../../../domain/repositories/driver_repository.dart';
import '../../../domain/entities/driver_order_entity.dart';

class GetDriverPendingUC {
  final DriverRepository repo;
  GetDriverPendingUC(this.repo);
  
  Future<List<DriverOrderEntity>> call() => repo.getDriverPending();
}
