import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../../../domain/entities/driver_order_entity.dart';
import '../../providers/use_case_providers.dart';

// Main Driver Controller
final driverControllerProvider = StateNotifierProvider<DriverController, DriverState>((ref) {
  return DriverController(ref);
});

class DriverState {
  final bool isLoading;
  final List<DriverOrderEntity> currentOrders;
  final List<DriverOrderEntity> pendingOrders;
  final String? error;

  const DriverState({
    this.isLoading = false,
    this.currentOrders = const [],
    this.pendingOrders = const [],
    this.error,
  });

  DriverState copyWith({
    bool? isLoading,
    List<DriverOrderEntity>? currentOrders,
    List<DriverOrderEntity>? pendingOrders,
    String? error,
  }) {
    return DriverState(
      isLoading: isLoading ?? this.isLoading,
      currentOrders: currentOrders ?? this.currentOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      error: error,
    );
  }
}

class DriverController extends StateNotifier<DriverState> {
  final Ref ref;

  DriverController(this.ref) : super(const DriverState());

  Future<void> loadCurrentOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uc = ref.read(getCurrentOrderPendingUCProvider);
      final orders = await uc.call();
      state = state.copyWith(isLoading: false, currentOrders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPendingOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uc = ref.read(getOrderPendingUCProvider);
      final orders = await uc.call();
      state = state.copyWith(isLoading: false, pendingOrders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Pending Orders
final driverPendingOrdersProvider = StateNotifierProvider<DriverPendingOrdersNotifier, AsyncValue<List<DriverOrderEntity>>>((ref) {
  return DriverPendingOrdersNotifier(ref);
});

class DriverPendingOrdersNotifier extends StateNotifier<AsyncValue<List<DriverOrderEntity>>> {
  final Ref ref;
  
  DriverPendingOrdersNotifier(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(getOrderPendingUCProvider);
      final items = await uc.call();
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> receive(String id) async {
    try {
      final receiveUC = ref.read(receiveOrderPendingUCProvider);
      await receiveUC.call(id: id);
      await load();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> acceptOrder(String orderId) async {
    try {
      final receiveUC = ref.read(receiveOrderPendingUCProvider);
      await receiveUC.call(id: orderId);
      await load();
    } catch (e) {
      // Handle error
    }
  }
}

// Current Orders
final driverCurrentOrdersProvider = StateNotifierProvider<DriverCurrentOrdersNotifier, AsyncValue<List<DriverOrderEntity>>>((ref) {
  return DriverCurrentOrdersNotifier(ref);
});

class DriverCurrentOrdersNotifier extends StateNotifier<AsyncValue<List<DriverOrderEntity>>> {
  final Ref ref;
  
  DriverCurrentOrdersNotifier(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(getCurrentOrderPendingUCProvider);
      final items = await uc.call();
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateStatus(String orderId, String status) async {
    try {
      final updateUC = ref.read(updateOrderStatusUCProvider);
      await updateUC.call(orderId: orderId, status: status);
      await load();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateOrderStatus(String orderId, int status) async {
    try {
      final updateUC = ref.read(updateOrderStatusUCProvider);
      await updateUC.call(orderId: orderId, status: status.toString());
      await load();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> changeAmount(String orderId, double newAmount) async {
    try {
      final changeUC = ref.read(driverChangeAmountUCProvider);
      await changeUC.call(orderId: orderId, newAmount: newAmount);
      await load();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> changeOrderAmount(String orderId, double newAmount) async {
    try {
      final changeUC = ref.read(driverChangeAmountUCProvider);
      await changeUC.call(orderId: orderId, newAmount: newAmount);
      await load();
    } catch (e) {
      // Handle error
    }
  }
}

// Driver Pending
final driverPendingProvider = StateNotifierProvider<DriverPendingNotifier, AsyncValue<List<DriverOrderEntity>>>((ref) {
  return DriverPendingNotifier(ref);
});

class DriverPendingNotifier extends StateNotifier<AsyncValue<List<DriverOrderEntity>>> {
  final Ref ref;
  
  DriverPendingNotifier(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final uc = ref.read(getDriverPendingUCProvider);
      final items = await uc.call();
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
