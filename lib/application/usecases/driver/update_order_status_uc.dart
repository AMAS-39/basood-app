import '../../../domain/repositories/driver_repository.dart';

class UpdateOrderStatusUC {
  final DriverRepository repo;
  UpdateOrderStatusUC(this.repo);
  
  Future<void> call({required String orderId, required String status}) =>
      repo.updateOrderStatus(orderId, status);
}
