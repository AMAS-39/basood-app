import '../../../domain/repositories/driver_repository.dart';

class ReceiveOrderPendingUC {
  final DriverRepository repo;
  ReceiveOrderPendingUC(this.repo);
  
  Future<void> call({required String id}) => repo.receiveOrderPending(id);
}
