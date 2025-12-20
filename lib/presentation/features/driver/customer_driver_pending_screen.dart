import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import 'driver_controller.dart';

class CustomerDriverPendingScreen extends ConsumerWidget {
  const CustomerDriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverPendingOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driverPendingOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading pending orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(driverPendingOrdersProvider.notifier).load(),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No Pending Orders',
              subtitle: 'New orders will appear here when available',
              icon: Icons.assignment_outlined,
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(driverPendingOrdersProvider.notifier).load(),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return OrderCard(
                  code: order.code,
                  from: order.pickupAddress,
                  to: order.dropoffAddress,
                  primaryLabel: 'Accept Order',
                  onPrimary: () => _showAcceptDialog(context, ref, order),
                  trailing: IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () => _showOrderDetails(context, order),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAcceptDialog(BuildContext context, WidgetRef ref, order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Text('Do you want to accept order ${order.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(driverPendingOrdersProvider.notifier).acceptOrder(order.id);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${order.pickupAddress}'),
            const SizedBox(height: 8),
            Text('To: ${order.dropoffAddress}'),
            const SizedBox(height: 8),
            Text('Created: ${_formatDate(order.createdAt)}'),
            if (order.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${order.note}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
