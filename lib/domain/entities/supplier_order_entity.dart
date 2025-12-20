import 'product_item.dart';

class SupplierOrderEntity {
  final String id;
  final String code;
  final String recipientName;
  final String phone;
  final String status;
  final String driverName;
  final bool isToCustomer;
  final String pickupAddress;
  final String dropoffAddress;
  final List<ProductItem> items;
  final double total;
  final DateTime createdAt;
  
  const SupplierOrderEntity({
    required this.id,
    required this.code,
    required this.recipientName,
    required this.phone,
    required this.status,
    required this.driverName,
    required this.isToCustomer,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.items,
    required this.total,
    required this.createdAt,
  });
}
