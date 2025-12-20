import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../../../infrastructure/dtos/dashboard_dtos.dart';
import '../../../domain/entities/supplier_order_entity.dart';
import '../../../domain/entities/payment_entity.dart';
import '../../../core/utils/pagination.dart';
import '../../providers/use_case_providers.dart';

// Supplier Orders Provider
final supplierOrdersProvider = StateNotifierProvider<SupplierOrdersNotifier, AsyncValue<PaginationResult<SupplierOrderEntity>>>((ref) {
  return SupplierOrdersNotifier(ref);
});

class SupplierOrdersNotifier extends StateNotifier<AsyncValue<PaginationResult<SupplierOrderEntity>>> {
  final Ref ref;
  
  SupplierOrdersNotifier(this.ref) : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(listSupplierOrdersUCProvider);
      final result = await uc.call();
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// Supplier Payments Provider
final supplierPaymentsProvider = StateNotifierProvider<SupplierPaymentsNotifier, AsyncValue<List<PaymentEntity>>>((ref) {
  return SupplierPaymentsNotifier(ref);
});

class SupplierPaymentsNotifier extends StateNotifier<AsyncValue<List<PaymentEntity>>> {
  final Ref ref;
  
  SupplierPaymentsNotifier(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(listSupplierPaymentsUCProvider);
      final payments = await uc.call();
      state = AsyncData(payments);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// Supplier Canceled Orders Provider
final supplierCanceledOrdersProvider = StateNotifierProvider<SupplierCanceledOrdersNotifier, AsyncValue<List<SupplierOrderEntity>>>((ref) {
  return SupplierCanceledOrdersNotifier(ref);
});

class SupplierCanceledOrdersNotifier extends StateNotifier<AsyncValue<List<SupplierOrderEntity>>> {
  final Ref ref;
  
  SupplierCanceledOrdersNotifier(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(getSupplierCanceledUCProvider);
      final items = await uc.call();
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> confirmReceived(String id) async {
    try {
      final confirmUC = ref.read(confirmReceivedCanceledUCProvider);
      await confirmUC.call(id: id);
      await load();
    } catch (e) {
      // Handle error
    }
  }
}

// Main Supplier Controller
final supplierControllerProvider = StateNotifierProvider<SupplierController, SupplierState>((ref) {
  return SupplierController(ref);
});

class SupplierState {
  final bool isLoading;
  final List<SupplierOrderEntity> orders;
  final List<SupplierOrderEntity> canceledOrders;
  final SupplierDashboardStatsDto? dashboardStats;
  final String? error;

  const SupplierState({
    this.isLoading = false,
    this.orders = const [],
    this.canceledOrders = const [],
    this.dashboardStats,
    this.error,
  });

  SupplierState copyWith({
    bool? isLoading,
    List<SupplierOrderEntity>? orders,
    List<SupplierOrderEntity>? canceledOrders,
    SupplierDashboardStatsDto? dashboardStats,
    String? error,
  }) {
    return SupplierState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      canceledOrders: canceledOrders ?? this.canceledOrders,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      error: error,
    );
  }
}

class SupplierController extends StateNotifier<SupplierState> {
  final Ref ref;

  SupplierController(this.ref) : super(const SupplierState()) {
    // Load initial data
    loadOrders();
    loadCanceledOrders();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uc = ref.read(listSupplierOrdersUCProvider);
      final result = await uc.call();
      state = state.copyWith(isLoading: false, orders: result.items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCanceledOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uc = ref.read(getSupplierCanceledUCProvider);
      final orders = await uc.call();
      state = state.copyWith(isLoading: false, canceledOrders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }


  // Statistics calculation methods
  int calculateActiveOrders() {
    return state.orders.where((order) => 
      order.status == 'Active' || order.status == 'In Progress'
    ).length;
  }

  int calculatePendingOrders() {
    return state.orders.where((order) => 
      order.status == 'Pending' || order.status == 'Awaiting Pickup'
    ).length;
  }

  int calculateDeliveredOrders() {
    return state.orders.where((order) => 
      order.status == 'Delivered' || order.status == 'Completed'
    ).length;
  }

  int calculateCanceledOrders() {
    return state.canceledOrders.length;
  }

  int calculateWeeklyOrders() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return state.orders.where((order) => 
      order.createdAt.isAfter(weekStart)
    ).length;
  }

  double calculateTotalPayments() {
    // This would need to be calculated from payments data
    // For now, return 0 as we don't have payments in the current state
    return 0.0;
  }
}