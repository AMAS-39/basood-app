import 'package:dio/dio.dart';
import '../../core/config/api_endpoints.dart';

class DashboardRemoteDS {
  final Dio dio;
  DashboardRemoteDS(this.dio);

  // Driver Order endpoints
  Future<Response> getDriverPendingOrders() => dio.get(BasoodEndpoints.driverOrder.orderPending);
  Future<Response> getDriverCurrentOrders() => dio.get(BasoodEndpoints.driverOrder.currentOrderPending);
  
  // Supplier Order endpoints
  Future<Response> getSupplierOrders() => dio.get(BasoodEndpoints.supplierOrder.getAll);
  Future<Response> getSupplierCanceledOrders() => dio.get(BasoodEndpoints.supplierOrder.supplierCurrentCancel);
  Future<Response> getSupplierPayments() => dio.get(BasoodEndpoints.supplier.payments);
}
