import '../../core/utils/pagination.dart';
import '../../domain/entities/payment_entity.dart';
import '../../domain/entities/supplier_order_entity.dart';
import '../../domain/entities/product_item.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/supplier_remote_ds.dart';
import '../dtos/supplier_order_dtos.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final SupplierRemoteDS ds;
  SupplierRepositoryImpl(this.ds);

  SupplierOrderEntity _mapOrder(Map<String, dynamic> json) {
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
    } else if (json['productName'] != null) {
      // Handle single product as an item
      items = [
        ProductItem(
          name: json['productName'] ?? '',
          quantity: 1,
          price: (json['productPrice'] ?? 0.0).toDouble(),
        ),
      ];
    }

    // Convert status integer to string
    String statusString = 'Pending';
    if (json['status'] != null) {
      if (json['status'] is String) {
        statusString = json['status'] as String;
      } else if (json['status'] is int) {
        final statusCode = json['status'] as int;
        // Map status codes to string
        switch (statusCode) {
          case 0:
            statusString = 'Pending';
            break;
          case 1:
            statusString = 'Active';
            break;
          case 2:
            statusString = 'Delivered';
            break;
          case 3:
            statusString = 'Canceled';
            break;
          default:
            statusString = 'Pending';
        }
      }
    }

    // Get driver name from nested object
    String driverName = '';
    if (json['driver'] != null && json['driver'] is Map) {
      final driver = json['driver'] as Map;
      final firstName = driver['firstName'] ?? '';
      final lastName = driver['lastName'] ?? '';
      driverName = '$firstName $lastName'.trim();
    } else if (json['driverName'] != null) {
      driverName = json['driverName'].toString();
    }

    // Calculate total from items if totalOrder is null or zero
    double calculatedTotal = 0.0;
    if (json['totalOrder'] != null) {
      calculatedTotal = (json['totalOrder'] ?? 0.0).toDouble();
    } else if (json['total'] != null) {
      calculatedTotal = (json['total'] ?? 0.0).toDouble();
    } else if (items.isNotEmpty) {
      // Calculate from items
      calculatedTotal = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    } else if (json['productPrice'] != null) {
      // Use productPrice as fallback
      calculatedTotal = (json['productPrice'] ?? 0.0).toDouble();
    }

    return SupplierOrderEntity(
      id: json['id']?.toString() ?? '',
      code: json['orderNo']?.toString() ?? '',
      recipientName: json['receiverName']?.toString() ?? '',
      phone: json['receiverPrimaryNumber']?.toString() ?? json['phone']?.toString() ?? '',
      status: statusString,
      driverName: driverName,
      isToCustomer: json['isToCustomer'] ?? false,
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffAddress: json['address'] ?? json['dropoffAddress'] ?? '',
      items: items,
      total: calculatedTotal,
      createdAt: DateTime.tryParse(json['createdDate'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  PaymentEntity _mapPayment(Map<String, dynamic> json) => PaymentEntity(
    id: json['id']?.toString() ?? '',
    amount: (json['amount'] ?? 0.0).toDouble(),
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    note: json['note'] ?? '',
  );

  @override
  Future<PaginationResult<SupplierOrderEntity>> listSupplierOrders({String? cursor}) async {
    final response = await ds.listSupplierOrders(cursor: cursor);
    final data = response.data as Map<String, dynamic>;
    
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final hasMore = data['hasMore'] ?? false;
    final nextCursor = data['nextCursor'];
    
    return PaginationResult(
      items: items.map(_mapOrder).toList(),
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

      @override
      Future<SupplierOrderEntity> createSupplierOrder(Map<String, dynamic> body) async {
        final dto = CreateSupplierOrderDto(
          productName: body['productName'] ?? '',
          productAmount: body['productAmount'] ?? 0,
          receiverPrimaryNumber: body['receiverPrimaryNumber'] ?? '',
          address: body['address'] ?? '',
          orderNo: body['orderNo'] ?? '',
          remark: body['remark'] ?? '',
          toCityId: body['toCityId'] ?? 1,
          neighborhoodId: body['neighborhoodId'] ?? 1,
          supplierId: body['supplierId'],
        );
        final response = await ds.createSupplierOrder(dto);
        return _mapOrder(response.data);
      }

  @override
  Future<List<SupplierOrderEntity>> listSupplierCurrentCancel() async {
    final response = await ds.listSupplierCurrentCancel();
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(_mapOrder).toList();
  }

  @override
  Future<void> confirmReceivedCanceled(String id) => ds.confirmReceivedCanceled(id);

  @override
  Future<SupplierOrderEntity> getSupplierOrderById(String id) async {
    final response = await ds.getSupplierOrderById(id);
    return _mapOrder(response.data);
  }

  @override
  Future<SupplierOrderEntity> updateSupplierOrder(String id, Map<String, dynamic> body) async {
    final response = await ds.updateSupplierOrder(id, body);
    return _mapOrder(response.data);
  }

  @override
  Future<List<PaymentEntity>> listPayments() async {
    final response = await ds.listPayments();
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(_mapPayment).toList();
  }
}
