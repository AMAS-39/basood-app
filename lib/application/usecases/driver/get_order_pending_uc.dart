import '../../../domain/repositories/driver_repository.dart';
import '../../../domain/entities/driver_order_entity.dart';

class GetOrderPendingUC {
  final DriverRepository repo;
  GetOrderPendingUC(this.repo);
  
  Future<List<DriverOrderEntity>> call() => repo.getOrderPending();
}
