import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/app_button.dart';
import '../../../domain/entities/supplier_order_entity.dart';
import '../../../domain/entities/product_item.dart';
import '../../providers/use_case_providers.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  SupplierOrderEntity? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uc = ref.read(getSupplierOrderDetailUCProvider);
      final order = await uc.call(id: widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading order details...')
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _loadOrderDetails,
                )
              : _order == null
                  ? const Center(
                      child: Text('Order not found'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Header
                          _buildOrderHeader(context, _order!),
                          const SizedBox(height: 24),

                          // Recipient Information
                          _buildRecipientInfo(context, _order!),
                          const SizedBox(height: 24),

                          // Driver Information (if assigned)
                          if (_order!.driverName.isNotEmpty) ...[
                            _buildDriverInfo(context, _order!),
                            const SizedBox(height: 24),
                          ],

                          // Product Items
                          _buildProductItems(context, _order!),
                          const SizedBox(height: 24),

                          // Order Summary
                          _buildOrderSummary(context, _order!),
                          const SizedBox(height: 24),

                          // Status Timeline
                          _buildStatusTimeline(context, _order!),
                          const SizedBox(height: 24),

                          // Action Buttons
                          _buildActionButtons(context, _order!),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, SupplierOrderEntity order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[800]!, Colors.teal[800]!.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${_formatDate(order.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Destination: ${order.isToCustomer ? 'To Customer' : 'To Supplier'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientInfo(BuildContext context, SupplierOrderEntity order) {
    return _buildInfoSection(
      context,
      'Recipient Information',
      Icons.person,
      [
        _buildInfoRow('Name', order.recipientName),
        _buildInfoRow('Phone', order.phone),
        _buildInfoRow('Address', order.dropoffAddress),
      ],
    );
  }

  Widget _buildDriverInfo(BuildContext context, SupplierOrderEntity order) {
    return _buildInfoSection(
      context,
      'Driver Information',
      Icons.local_shipping,
      [
        _buildInfoRow('Driver Name', order.driverName),
        _buildInfoRow('Pickup Address', order.pickupAddress),
      ],
    );
  }

  Widget _buildProductItems(BuildContext context, SupplierOrderEntity order) {
    return _buildInfoSection(
      context,
      'Product Items',
      Icons.inventory,
      order.items.map((item) => _buildProductItemRow(item)).toList(),
    );
  }

  Widget _buildProductItemRow(ProductItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              'Qty: ${item.quantity}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '\$${(item.price * item.quantity).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, SupplierOrderEntity order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context, SupplierOrderEntity order) {
    // Build timeline based on actual status
    List<Widget> timelineItems = [
      _buildTimelineItem('Order Created', order.createdAt, true),
    ];
    
    // Add status-specific items
    if (order.status == 'Active' || order.status == 'Delivered') {
      timelineItems.add(_buildTimelineItem('Order ${order.status}', order.createdAt, true));
    }
    
    if (order.status == 'Delivered') {
      timelineItems.add(_buildTimelineItem('Completed', order.createdAt, true));
    }
    
    if (order.status == 'Canceled') {
      timelineItems.add(_buildTimelineItem('Order Canceled', order.createdAt, false));
    }
    
    return _buildInfoSection(
      context,
      'Order Status',
      Icons.timeline,
      timelineItems,
    );
  }

  Widget _buildTimelineItem(String title, DateTime date, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: isCompleted ? Colors.green[600] : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.green[800] : Colors.grey[800],
                  ),
                ),
                Text(
                  _formatDateTime(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SupplierOrderEntity order) {
    return Column(
      children: [
        if (order.status == 'Pending' || order.status == 'Active') ...[
          AppButton(
            text: 'Edit Order',
            onPressed: () {
              // TODO: Navigate to edit order screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality coming soon')),
              );
            },
            isPrimary: true,
          ),
          const SizedBox(height: 12),
        ],
        AppButton(
          text: 'Share Order',
          onPressed: () {
            // TODO: Share order details
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share functionality coming soon')),
            );
          },
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal[800], size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'active':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case 'delivered':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'canceled':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
