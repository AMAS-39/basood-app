import '../../domain/entities/driver_order_entity.dart';
import '../../domain/repositories/driver_repository.dart';
import '../datasources/driver_remote_ds.dart';
import '../dtos/driver_order_dtos.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverRemoteDS ds;
  DriverRepositoryImpl(this.ds);

  DriverOrderEntity _mapOrder(Map<String, dynamic> json) => DriverOrderEntity(
    id: json['id']?.toString() ?? '',
    code: json['code'] ?? '',
    pickupAddress: json['pickupAddress'] ?? '',
    dropoffAddress: json['dropoffAddress'] ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );

  @override
  Future<List<DriverOrderEntity>> getOrderPending() async {
    final response = await ds.getOrderPending();
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(_mapOrder).toList();
  }

  @override
  Future<void> receiveOrderPending(String id) => ds.receiveOrderPending(id);

  @override
  Future<List<DriverOrderEntity>> getCurrentOrderPending() async {
    final response = await ds.getCurrentOrderPending();
    // Handle paginated response structure
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];
      final list = items.cast<Map<String, dynamic>>();
      return list.map(_mapOrder).toList();
    } else {
      // Fallback for non-paginated responses
      final list = (response.data as List).cast<Map<String, dynamic>>();
      return list.map(_mapOrder).toList();
    }
  }

  @override
  Future<List<DriverOrderEntity>> getDriverPending() async {
    final response = await ds.getDriverPending();
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(_mapOrder).toList();
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) =>
      ds.updateOrderStatus(orderId, UpdateOrderStatusDto(status: status));

  @override
  Future<void> changeAmount(String orderId, double newAmount) =>
      ds.changeAmount(orderId, ChangeAmountDto(newAmount: newAmount));
}
