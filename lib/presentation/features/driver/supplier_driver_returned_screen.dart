import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_button.dart';
import '../supplier/supplier_controller.dart';

class SupplierDriverReturnedScreen extends ConsumerWidget {
  const SupplierDriverReturnedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierCanceledOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Returned Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supplierCanceledOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading returned orders...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(supplierCanceledOrdersProvider.notifier).load(),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No Returned Orders',
              subtitle: 'Canceled orders will appear here',
              icon: Icons.assignment_returned,
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(supplierCanceledOrdersProvider.notifier).load(),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
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
                              label: const Text(
                                'Returned',
                                style: TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              backgroundColor: Colors.red.shade600,
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
                        AppButton(
                          text: 'Confirm Received',
                          onPressed: () => _showConfirmDialog(context, ref, order),
                          isPrimary: true,
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

  void _showConfirmDialog(BuildContext context, WidgetRef ref, order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Received'),
        content: Text('Have you received the returned order ${order.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(supplierCanceledOrdersProvider.notifier).confirmReceived(order.id);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order confirmed as received'),
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
