import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../../domain/entities/payment_entity.dart';
import 'supplier_controller.dart';

class SupplierPaymentsScreen extends ConsumerStatefulWidget {
  const SupplierPaymentsScreen({super.key});

  @override
  ConsumerState<SupplierPaymentsScreen> createState() => _SupplierPaymentsScreenState();
}

class _SupplierPaymentsScreenState extends ConsumerState<SupplierPaymentsScreen> {
  String _sortBy = 'date'; // 'date', 'amount'
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierPaymentsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == _sortBy) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = false;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'date' 
                          ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                          : Icons.sort,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'amount' 
                          ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                          : Icons.sort,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Amount'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supplierPaymentsProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading payments...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(supplierPaymentsProvider.notifier).load(),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return const EmptyState(
              title: 'No Payments',
              subtitle: 'Payments from office will appear here',
              icon: Icons.payment_outlined,
            );
          }

          final sortedPayments = _sortPayments(payments);
          final totalReceived = _calculateTotalReceived(sortedPayments);
          final completedPayments = _countCompletedPayments(sortedPayments);
          final pendingPayments = _countPendingPayments(sortedPayments);
          
          return RefreshIndicator(
            onRefresh: () => ref.read(supplierPaymentsProvider.notifier).load(),
            child: Column(
              children: [
                // Summary Card
                _buildSummaryCard(context, totalReceived, completedPayments, pendingPayments),
                
                // Payments List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedPayments.length,
                    itemBuilder: (context, index) {
                      final payment = sortedPayments[index];
                      return _buildPaymentCard(context, payment);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double totalReceived, int completedPayments, int pendingPayments) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[800]!, Colors.purple[800]!.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Total Received',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              Text(
                '\$${totalReceived.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  context,
                  'Completed',
                  completedPayments.toString(),
                  Colors.green[100]!,
                  Colors.green[800]!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  'Pending',
                  pendingPayments.toString(),
                  Colors.orange[100]!,
                  Colors.orange[800]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentEntity payment) {
    final isCompleted = payment.note.toLowerCase().contains('completed') || 
                        payment.note.toLowerCase().contains('received');
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isCompleted ? Colors.green[100]! : Colors.orange[100]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: statusColor[800],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${payment.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        _formatDate(payment.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(isCompleted),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Reference ID (if available)
            if (payment.id.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Ref: ${payment.id.substring(0, 8).toUpperCase()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Note
            if (payment.note.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  payment.note,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: isCompleted ? Colors.green[800] : Colors.orange[800],
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted ? 'Completed' : 'Pending',
            style: TextStyle(
              color: isCompleted ? Colors.green[800] : Colors.orange[800],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<PaymentEntity> _sortPayments(List<PaymentEntity> payments) {
    final sorted = List<PaymentEntity>.from(payments);
    
    if (_sortBy == 'date') {
      sorted.sort((a, b) {
        final comparison = a.date.compareTo(b.date);
        return _sortAscending ? comparison : -comparison;
      });
    } else if (_sortBy == 'amount') {
      sorted.sort((a, b) {
        final comparison = a.amount.compareTo(b.amount);
        return _sortAscending ? comparison : -comparison;
      });
    }
    
    return sorted;
  }

  double _calculateTotalReceived(List<PaymentEntity> payments) {
    return payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  int _countCompletedPayments(List<PaymentEntity> payments) {
    return payments.where((payment) => 
      payment.note.toLowerCase().contains('completed') || 
      payment.note.toLowerCase().contains('received')
    ).length;
  }

  int _countPendingPayments(List<PaymentEntity> payments) {
    return payments.where((payment) => 
      !payment.note.toLowerCase().contains('completed') && 
      !payment.note.toLowerCase().contains('received')
    ).length;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
