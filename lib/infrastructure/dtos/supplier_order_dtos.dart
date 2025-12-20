import '../../domain/entities/product_item.dart';

class SupplierOrderDto {
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
  final String createdAt;

  const SupplierOrderDto({
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

  factory SupplierOrderDto.fromJson(Map<String, dynamic> json) {
    // Parse items array
    List<ProductItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List).map((item) {
        return ProductItem(
          name: item['name'] ?? '',
          quantity: item['quantity'] ?? 0,
          price: (item['price'] ?? 0.0).toDouble(),
        );
      }).toList();
    }

    return SupplierOrderDto(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      recipientName: json['recipientName'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'Pending',
      driverName: json['driverName'] ?? '',
      isToCustomer: json['isToCustomer'] ?? false,
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffAddress: json['dropoffAddress'] ?? '',
      items: items,
      total: (json['total'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class CreateSupplierOrderDto {
  final String productName;
  final int productAmount;
  final String receiverPrimaryNumber;
  final String address;
  final String orderNo;
  final String remark;
  final int toCityId;
  final int neighborhoodId;
  final int? supplierId;

  const CreateSupplierOrderDto({
    required this.productName,
    required this.productAmount,
    required this.receiverPrimaryNumber,
    required this.address,
    required this.orderNo,
    required this.remark,
    required this.toCityId,
    required this.neighborhoodId,
    this.supplierId,
  });

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'productAmount': productAmount,
    'ReceiverPrimaryNumber': receiverPrimaryNumber,
    'address': address,
    'OrderNo': orderNo,
    'remark': remark,
    'ToCityId': toCityId,
    'NeighborhoodId': neighborhoodId,
    if (supplierId != null) 'supplierId': supplierId,
  };
}
