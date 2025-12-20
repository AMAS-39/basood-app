import '../entities/driver_order_entity.dart';

abstract class DriverRepository {
  Future<List<DriverOrderEntity>> getOrderPending();
  Future<void> receiveOrderPending(String id); // PUT /ReceivedOrderPending/{id}
  Future<List<DriverOrderEntity>> getCurrentOrderPending();
  Future<List<DriverOrderEntity>> getDriverPending();
  Future<void> updateOrderStatus(String orderId, String status); // PUT /Order/Status/{id}
  Future<void> changeAmount(String orderId, double newAmount); // PUT /DriverChangeAmount/{id}
}
