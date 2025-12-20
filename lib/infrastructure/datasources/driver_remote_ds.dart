import 'package:dio/dio.dart';
import '../../core/config/api_endpoints.dart';
import '../dtos/driver_order_dtos.dart';

class DriverRemoteDS {
  final Dio dio;
  DriverRemoteDS(this.dio);

  Future<Response> getOrderPending() => dio.get(BasoodEndpoints.driverOrder.orderPending);
  
  Future<Response> receiveOrderPending(String id) => 
      dio.put('${BasoodEndpoints.driverOrder.receivedOrderPending}/$id');
  
  Future<Response> getCurrentOrderPending() => 
      dio.get(BasoodEndpoints.driverOrder.currentDriverPending);
  
  Future<Response> getDriverPending() => dio.get(BasoodEndpoints.driverOrder.driverPending);
  
  Future<Response> updateOrderStatus(String id, UpdateOrderStatusDto dto) =>
      dio.put(BasoodEndpoints.order.status(id), data: dto.toJson());
  
  Future<Response> changeAmount(String id, ChangeAmountDto dto) =>
      dio.put(BasoodEndpoints.driverOrder.driverChangeAmount(id), data: dto.toJson());
}
