import 'package:dio/dio.dart';
import '../../core/config/api_endpoints.dart';
import '../dtos/supplier_order_dtos.dart';

class SupplierRemoteDS {
  final Dio dio;
  SupplierRemoteDS(this.dio);

  Future<Response> listSupplierOrders({String? cursor}) {
    final queryParams = cursor != null ? {'cursor': cursor} : null;
    return dio.get(BasoodEndpoints.supplierOrder.getAll, queryParameters: queryParams);
  }

  Future<Response> createSupplierOrder(CreateSupplierOrderDto dto) =>
      dio.post(BasoodEndpoints.supplierOrder.create, data: dto.toJson());

  Future<Response> listSupplierCurrentCancel() =>
      dio.get(BasoodEndpoints.supplierOrder.supplierCurrentCancel);

  Future<Response> confirmReceivedCanceled(String id) =>
      dio.put(BasoodEndpoints.supplierOrder.receivedOrderCanceled(id));

  Future<Response> getSupplierOrderById(String id) =>
      dio.get(BasoodEndpoints.supplierOrder.getById(id));

  Future<Response> updateSupplierOrder(String id, Map<String, dynamic> data) =>
      dio.put(BasoodEndpoints.supplierOrder.update(id), data: data);

  Future<Response> listPayments() => dio.get(BasoodEndpoints.supplier.payments);
}
