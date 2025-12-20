import '../../../domain/repositories/supplier_repository.dart';

class ConfirmReceivedCanceledUC {
  final SupplierRepository repo;
  ConfirmReceivedCanceledUC(this.repo);
  
  Future<void> call({required String id}) => repo.confirmReceivedCanceled(id);
}
