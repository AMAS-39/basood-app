import '../entities/payment_entity.dart';
import '../entities/supplier_order_entity.dart';
import '../../core/utils/pagination.dart';

abstract class SupplierRepository {
  Future<PaginationResult<SupplierOrderEntity>> listSupplierOrders({String? cursor});
  Future<SupplierOrderEntity> createSupplierOrder(Map<String, dynamic> body);
  Future<List<SupplierOrderEntity>> listSupplierCurrentCancel();
  Future<void> confirmReceivedCanceled(String id);
  Future<SupplierOrderEntity> getSupplierOrderById(String id);
  Future<SupplierOrderEntity> updateSupplierOrder(String id, Map<String, dynamic> body);
  Future<List<PaymentEntity>> listPayments();
}
