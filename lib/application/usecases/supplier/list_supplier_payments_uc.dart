import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/payment_entity.dart';

class ListSupplierPaymentsUC {
  final SupplierRepository repo;
  ListSupplierPaymentsUC(this.repo);
  
  Future<List<PaymentEntity>> call() => repo.listPayments();
}
