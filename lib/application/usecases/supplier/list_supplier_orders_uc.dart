import '../../../core/utils/pagination.dart';
import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/supplier_order_entity.dart';

class ListSupplierOrdersUC {
  final SupplierRepository repo;
  ListSupplierOrdersUC(this.repo);
  
  Future<PaginationResult<SupplierOrderEntity>> call({String? cursor}) =>
      repo.listSupplierOrders(cursor: cursor);
}
