import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/supplier_order_entity.dart';

class UpdateSupplierOrderUC {
  final SupplierRepository repo;
  UpdateSupplierOrderUC(this.repo);
  
  Future<SupplierOrderEntity> call({
    required String id,
    required Map<String, dynamic> body,
  }) => repo.updateSupplierOrder(id, body);
}
