import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_update_modal.dart';
import 'driver_controller.dart';

class CustomerDriverCurrentScreen extends ConsumerWidget {
  const CustomerDriverCurrentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverCurrentOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driverCurrentOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading current orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(driverCurrentOrdersProvider.notifier).load(),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No Current Orders',
              subtitle: 'Accept orders from the Pending Orders screen',
              icon: Icons.assignment_outlined,
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(driverCurrentOrdersProvider.notifier).load(),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return OrderCard(
                  code: order.code,
                  from: order.pickupAddress,
                  to: order.dropoffAddress,
                  primaryLabel: 'Update Status',
                  onPrimary: () => _showStatusDialog(context, ref, order),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'change_amount',
                        child: const Text('Change Amount'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'change_amount') {
                        _showAmountDialog(context, ref, order);
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref, order) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatusUpdateModal(
        orderCode: order.code,
        onStatusSelected: (status) => _updateStatus(context, ref, order, status),
      ),
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, order, String status) {
    Navigator.of(context).pop();
    ref.read(driverCurrentOrdersProvider.notifier).updateStatus(order.id, status);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to $status'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAmountDialog(BuildContext context, WidgetRef ref, order) {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Amount'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Amount',
            prefixText: '\$',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final newAmount = double.tryParse(amountController.text);
              if (newAmount != null) {
                ref.read(driverCurrentOrdersProvider.notifier).changeOrderAmount(order.id, newAmount);
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Amount updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
