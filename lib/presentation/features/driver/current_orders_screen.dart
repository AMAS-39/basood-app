import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_button.dart';
import '../../../core/utils/status_codes.dart';
import 'driver_controller.dart';

class DriverCurrentOrdersScreen extends ConsumerWidget {
  const DriverCurrentOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverCurrentOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driverCurrentOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading your orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(driverCurrentOrdersProvider.notifier).load(),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No Current Orders',
              subtitle: 'Accept orders from the Available tab',
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
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showAmountDialog(context, ref, order),
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Order Status',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildStatusOption(context, ref, order, DriverStatus.driverPickup, 'Picked Up'),
            _buildStatusOption(context, ref, order, DriverStatus.delivered, 'Delivered'),
            _buildStatusOption(context, ref, order, DriverStatus.postponed, 'Postponed'),
            _buildStatusOption(context, ref, order, DriverStatus.canceled, 'Canceled'),
            _buildStatusOption(context, ref, order, DriverStatus.partialCanceled, 'Partially Canceled'),
            const SizedBox(height: 16),
            AppButton(
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(BuildContext context, WidgetRef ref, order, String status, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppButton(
        text: label,
        onPressed: () {
          Navigator.of(context).pop();
          ref.read(driverCurrentOrdersProvider.notifier).updateStatus(order.id, status);
        },
        isPrimary: false,
      ),
    );
  }

  void _showAmountDialog(BuildContext context, WidgetRef ref, order) {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter new amount:'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null) {
                Navigator.of(context).pop();
                ref.read(driverCurrentOrdersProvider.notifier).changeAmount(order.id, amount);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
