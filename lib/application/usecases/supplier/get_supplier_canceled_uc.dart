import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/supplier_order_entity.dart';

class GetSupplierCanceledUC {
  final SupplierRepository repo;
  GetSupplierCanceledUC(this.repo);
  
  Future<List<SupplierOrderEntity>> call() => repo.listSupplierCurrentCancel();
}
