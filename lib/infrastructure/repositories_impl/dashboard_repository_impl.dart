import '../../../domain/repositories/dashboard_repository.dart';
import '../../../infrastructure/datasources/dashboard_remote_ds.dart';
import '../../../infrastructure/dtos/dashboard_dtos.dart';
import '../../../core/errors/app_failure.dart';
import 'package:dio/dio.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDS ds;
  DashboardRepositoryImpl(this.ds);

  @override
  Future<DashboardStatsDto> getDriverStats() async {
    try {
      // Calculate driver stats from existing order endpoints
      final pendingOrders = await ds.getDriverPendingOrders();
      final currentOrders = await ds.getDriverCurrentOrders();
      
      // Count different statuses from the orders
      int undeliveredReceipts = 0;
      int cashReceipts = 0;
      int exchangeAndReturns = 0;
      int todaysCuts = 0;
      int reachedRecipient = 0;
      int receivedAtOffice = 0;
      int preparedForDistribution = 0;
      int returned = 0;
      int communicationProblem = 0;
      int delayed = 0;
      int technicalProblem = 0;
      
      // Process pending orders
      if (pendingOrders.data is List) {
        final orders = pendingOrders.data as List;
        undeliveredReceipts = orders.length;
      }
      
      // Process current orders
      if (currentOrders.data is List) {
        final orders = currentOrders.data as List;
        for (var order in orders) {
          // Count based on order status or other properties
          // This is a simplified calculation - adjust based on actual order structure
          if (order['status'] == 'Delivered') {
            reachedRecipient++;
          } else if (order['status'] == 'Returned') {
            returned++;
          } else if (order['status'] == 'Delayed') {
            delayed++;
          }
        }
      }
      
      return DashboardStatsDto(
        undeliveredReceipts: undeliveredReceipts,
        cashReceipts: cashReceipts,
        exchangeAndReturns: exchangeAndReturns,
        todaysCuts: todaysCuts,
        reachedRecipient: reachedRecipient,
        receivedAtOffice: receivedAtOffice,
        preparedForDistribution: preparedForDistribution,
        returned: returned,
        communicationProblem: communicationProblem,
        delayed: delayed,
        technicalProblem: technicalProblem,
      );
    } catch (e) {
      // Return empty stats if there's an error
      return const DashboardStatsDto(
        undeliveredReceipts: 0,
        cashReceipts: 0,
        exchangeAndReturns: 0,
        todaysCuts: 0,
        reachedRecipient: 0,
        receivedAtOffice: 0,
        preparedForDistribution: 0,
        returned: 0,
        communicationProblem: 0,
        delayed: 0,
        technicalProblem: 0,
      );
    }
  }

  @override
  Future<SupplierDashboardStatsDto> getSupplierStats() async {
    try {
      // Calculate supplier stats from existing order endpoints
      final supplierOrders = await ds.getSupplierOrders();
      final canceledOrders = await ds.getSupplierCanceledOrders();
      final payments = await ds.getSupplierPayments();
      
      // Count different statuses from the orders
      int todaysOrders = 0;
      int totalOrders = 0;
      int pendingOrders = 0;
      int deliveredOrders = 0;
      int canceledOrdersCount = 0;
      int totalPayments = 0;
      int delayedOrders = 0;
      int technicalProblems = 0;
      
      // Process supplier orders
      if (supplierOrders.data is List) {
        final orders = supplierOrders.data as List;
        totalOrders = orders.length;
        
        for (var order in orders) {
          // Count based on order status or creation date
          if (order['status'] == 'Pending') {
            pendingOrders++;
          } else if (order['status'] == 'Delivered') {
            deliveredOrders++;
          } else if (order['status'] == 'Delayed') {
            delayedOrders++;
          }
          
          // Check if order was created today
          final createdAt = order['createdAt'];
          if (createdAt != null) {
            final orderDate = DateTime.parse(createdAt);
            final today = DateTime.now();
            if (orderDate.year == today.year && 
                orderDate.month == today.month && 
                orderDate.day == today.day) {
              todaysOrders++;
            }
          }
        }
      }
      
      // Process canceled orders
      if (canceledOrders.data is List) {
        canceledOrdersCount = canceledOrders.data.length;
      }
      
      // Process payments
      if (payments.data is List) {
        final paymentList = payments.data as List;
        totalPayments = paymentList.length;
      }
      
      return SupplierDashboardStatsDto(
        todaysOrders: todaysOrders,
        totalOrders: totalOrders,
        pendingOrders: pendingOrders,
        deliveredOrders: deliveredOrders,
        canceledOrders: canceledOrdersCount,
        totalPayments: totalPayments,
        delayedOrders: delayedOrders,
        technicalProblems: technicalProblems,
      );
    } catch (e) {
      // Return empty stats if there's an error
      return const SupplierDashboardStatsDto(
        todaysOrders: 0,
        totalOrders: 0,
        pendingOrders: 0,
        deliveredOrders: 0,
        canceledOrders: 0,
        totalPayments: 0,
        delayedOrders: 0,
        technicalProblems: 0,
      );
    }
  }
}
