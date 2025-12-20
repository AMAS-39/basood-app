import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../../core/utils/status_codes.dart';
import 'driver_controller.dart';

class SupplierDriverCurrentScreen extends ConsumerWidget {
  const SupplierDriverCurrentScreen({super.key});

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Picked Up'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.pickedUp),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Delivered to Company'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.delivered),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_returned),
              title: const Text('Returned'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.returned),
            ),
            ListTile(
              leading: const Icon(Icons.error),
              title: const Text('Problem'),
              onTap: () => _showProblemDialog(context, ref, order),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, order, int status) {
    Navigator.of(context).pop();
    ref.read(driverCurrentOrdersProvider.notifier).updateOrderStatus(order.id, status);
  }

  void _showProblemDialog(BuildContext context, WidgetRef ref, order) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Problem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Delayed'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.delayed),
            ),
            ListTile(
              leading: const Icon(Icons.phone_disabled),
              title: const Text('Communication Problem'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.communicationProblem),
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Technical Problem'),
              onTap: () => _updateStatus(context, ref, order, StatusCodes.technicalProblem),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
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
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
