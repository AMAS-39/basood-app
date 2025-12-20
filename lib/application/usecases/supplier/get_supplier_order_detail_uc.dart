import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/supplier_order_entity.dart';

class GetSupplierOrderDetailUC {
  final SupplierRepository repo;
  GetSupplierOrderDetailUC(this.repo);
  
  Future<SupplierOrderEntity> call({required String id}) =>
      repo.getSupplierOrderById(id);
}
