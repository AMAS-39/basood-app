import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import 'driver_controller.dart';

class DriverPendingOrdersScreen extends ConsumerWidget {
  const DriverPendingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverPendingOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driverPendingOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading available orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(driverPendingOrdersProvider.notifier).load(),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No Available Orders',
              subtitle: 'Check back later for new orders',
              icon: Icons.inbox_outlined,
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
        content: Text('Are you sure you want to accept order ${order.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(driverPendingOrdersProvider.notifier).receive(order.id);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
