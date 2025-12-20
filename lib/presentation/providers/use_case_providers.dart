import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../application/usecases/login_mobile_usecase.dart';
import '../../application/usecases/refresh_token_usecase.dart';
import '../../application/usecases/driver/get_order_pending_uc.dart';
import '../../application/usecases/driver/receive_order_pending_uc.dart';
import '../../application/usecases/driver/get_current_order_pending_uc.dart';
import '../../application/usecases/driver/get_driver_pending_uc.dart';
import '../../application/usecases/driver/update_order_status_uc.dart';
import '../../application/usecases/driver/driver_change_amount_uc.dart';
import '../../application/usecases/supplier/list_supplier_orders_uc.dart';
import '../../application/usecases/supplier/create_supplier_order_uc.dart';
import '../../application/usecases/supplier/get_supplier_canceled_uc.dart';
import '../../application/usecases/supplier/confirm_received_canceled_uc.dart';
import '../../application/usecases/supplier/get_supplier_order_detail_uc.dart';
import '../../application/usecases/supplier/update_supplier_order_uc.dart';
import '../../application/usecases/supplier/list_supplier_payments_uc.dart';
import '../../application/usecases/notification/list_notifications_uc.dart';
import '../../application/usecases/notification/mark_notification_read_uc.dart';
import '../../application/usecases/dashboard_usecases.dart';
import 'di_providers.dart';

// Auth use cases
final loginMobileUCProvider = Provider<LoginMobileUC>((ref) {
  return LoginMobileUC(ref.read(authRepositoryProvider));
});

final refreshTokenUCProvider = Provider<RefreshTokenUC>((ref) {
  return RefreshTokenUC(ref.read(authRepositoryProvider));
});

// Driver use cases
final getOrderPendingUCProvider = Provider<GetOrderPendingUC>((ref) {
  return GetOrderPendingUC(ref.read(driverRepositoryProvider));
});

final receiveOrderPendingUCProvider = Provider<ReceiveOrderPendingUC>((ref) {
  return ReceiveOrderPendingUC(ref.read(driverRepositoryProvider));
});

final getCurrentOrderPendingUCProvider = Provider<GetCurrentOrderPendingUC>((
  ref,
) {
  return GetCurrentOrderPendingUC(ref.read(driverRepositoryProvider));
});

final getDriverPendingUCProvider = Provider<GetDriverPendingUC>((ref) {
  return GetDriverPendingUC(ref.read(driverRepositoryProvider));
});

final updateOrderStatusUCProvider = Provider<UpdateOrderStatusUC>((ref) {
  return UpdateOrderStatusUC(ref.read(driverRepositoryProvider));
});

final driverChangeAmountUCProvider = Provider<DriverChangeAmountUC>((ref) {
  return DriverChangeAmountUC(ref.read(driverRepositoryProvider));
});

// Supplier use cases
final listSupplierOrdersUCProvider = Provider<ListSupplierOrdersUC>((ref) {
  return ListSupplierOrdersUC(ref.read(supplierRepositoryProvider));
});

final createSupplierOrderUCProvider = Provider<CreateSupplierOrderUC>((ref) {
  return CreateSupplierOrderUC(ref.read(supplierRepositoryProvider));
});

final getSupplierCanceledUCProvider = Provider<GetSupplierCanceledUC>((ref) {
  return GetSupplierCanceledUC(ref.read(supplierRepositoryProvider));
});

final confirmReceivedCanceledUCProvider = Provider<ConfirmReceivedCanceledUC>((
  ref,
) {
  return ConfirmReceivedCanceledUC(ref.read(supplierRepositoryProvider));
});

final getSupplierOrderDetailUCProvider = Provider<GetSupplierOrderDetailUC>((
  ref,
) {
  return GetSupplierOrderDetailUC(ref.read(supplierRepositoryProvider));
});

final updateSupplierOrderUCProvider = Provider<UpdateSupplierOrderUC>((ref) {
  return UpdateSupplierOrderUC(ref.read(supplierRepositoryProvider));
});

final listSupplierPaymentsUCProvider = Provider<ListSupplierPaymentsUC>((ref) {
  return ListSupplierPaymentsUC(ref.read(supplierRepositoryProvider));
});

// Notification use cases
final listNotificationsUCProvider = Provider<ListNotificationsUC>((ref) {
  return ListNotificationsUC(ref.read(notificationRepositoryProvider));
});

final markNotificationReadUCProvider = Provider<MarkNotificationReadUC>((ref) {
  return MarkNotificationReadUC(ref.read(notificationRepositoryProvider));
});

// Dashboard use cases
final getDriverStatsUCProvider = Provider<GetDriverStatsUC>((ref) {
  return GetDriverStatsUC(ref.read(dashboardRepositoryProvider));
});

final getSupplierStatsUCProvider = Provider<GetSupplierStatsUC>((ref) {
  return GetSupplierStatsUC(ref.read(dashboardRepositoryProvider));
});
