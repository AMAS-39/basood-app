import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_button.dart';
import '../supplier/supplier_controller.dart';

class SupplierDriverOrdersScreen extends ConsumerWidget {
  const SupplierDriverOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supplierOrdersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading supplier orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(supplierOrdersProvider.notifier).refresh(),
        ),
        data: (result) {
          if (result.items.isEmpty) {
            return const EmptyState(
              title: 'No Supplier Orders',
              subtitle: 'Orders between suppliers will appear here',
              icon: Icons.business,
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(supplierOrdersProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: result.items.length,
              itemBuilder: (context, index) {
                final order = result.items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              order.code,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Chip(
                              label: Text(
                                order.isToCustomer ? 'To Customer' : 'To Supplier',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: order.isToCustomer 
                                  ? Colors.blue.shade100 
                                  : Colors.green.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From: ${order.pickupAddress}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To: ${order.dropoffAddress}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Created: ${_formatDate(order.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                text: 'Mark as Delivered',
                                onPressed: () => _showDeliveredDialog(context, order),
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDeliveredDialog(BuildContext context, order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: Text('Confirm that order ${order.code} has been delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement mark as delivered functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order marked as delivered'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
