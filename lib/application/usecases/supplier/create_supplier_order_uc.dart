import '../../../domain/repositories/supplier_repository.dart';
import '../../../domain/entities/supplier_order_entity.dart';

class CreateSupplierOrderUC {
  final SupplierRepository repo;
  CreateSupplierOrderUC(this.repo);
  
      Future<SupplierOrderEntity> call({
        required String productName,
        required int productAmount,
        required String receiverPrimaryNumber,
        required String address,
        required String orderNo,
        required String remark,
        required int toCityId,
        required int neighborhoodId,
        required int supplierId,
      }) async {
        // Create the request body matching the API format
        final body = {
          'productName': productName,
          'productAmount': productAmount,
          'receiverPrimaryNumber': receiverPrimaryNumber,
          'address': address,
          'orderNo': orderNo,
          'remark': remark,
          'toCityId': toCityId,
          'neighborhoodId': neighborhoodId,
          'supplierId': supplierId,
        };
        
        return await repo.createSupplierOrder(body);
      }
}
