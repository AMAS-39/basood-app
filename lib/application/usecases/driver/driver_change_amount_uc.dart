import '../../../domain/repositories/driver_repository.dart';

class DriverChangeAmountUC {
  final DriverRepository repo;
  DriverChangeAmountUC(this.repo);
  
  Future<void> call({required String orderId, required double newAmount}) =>
      repo.changeAmount(orderId, newAmount);
}
