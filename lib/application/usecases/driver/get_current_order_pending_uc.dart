import '../../../domain/repositories/driver_repository.dart';
import '../../../domain/entities/driver_order_entity.dart';

class GetCurrentOrderPendingUC {
  final DriverRepository repo;
  GetCurrentOrderPendingUC(this.repo);
  
  Future<List<DriverOrderEntity>> call() => repo.getCurrentOrderPending();
}
