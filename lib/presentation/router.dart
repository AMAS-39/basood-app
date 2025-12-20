import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/driver/pending_orders_screen.dart';
import 'features/driver/current_orders_screen.dart';
import 'features/driver/customer_driver_home_screen.dart';
import 'features/driver/supplier_driver_pending_screen.dart';
import 'features/driver/supplier_driver_current_screen.dart';
import 'features/supplier/supplier_home_screen.dart';
import 'features/supplier/orders_list_screen.dart';
import 'features/supplier/create_order_screen.dart';
import 'features/supplier/canceled_orders_screen.dart';
import 'features/supplier/payments_screen.dart';

class AppRouter {
  static const String login = '/login';
  static const String driver = '/driver';
  static const String driverPending = '/driver/pending';
  static const String driverCurrent = '/driver/current';
  static const String supplierDriverPending = '/supplier-driver/pending';
  static const String supplierDriverCurrent = '/supplier-driver/current';
  static const String supplier = '/supplier';
  static const String supplierOrders = '/supplier/orders';
  static const String supplierCreateOrder = '/supplier/create-order';
  static const String supplierCanceled = '/supplier/canceled';
  static const String supplierPayments = '/supplier/payments';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case driver:
        return MaterialPageRoute(
          builder: (_) => const CustomerDriverHomeScreen(),
        );
      
      case driverPending:
        return MaterialPageRoute(
          builder: (_) => const DriverPendingOrdersScreen(),
        );
      
          case driverCurrent:
            return MaterialPageRoute(
              builder: (_) => const DriverCurrentOrdersScreen(),
            );

          case supplierDriverPending:
            return MaterialPageRoute(
              builder: (_) => const SupplierDriverPendingScreen(),
            );

          case supplierDriverCurrent:
            return MaterialPageRoute(
              builder: (_) => const SupplierDriverCurrentScreen(),
            );
      
      case supplier:
        return MaterialPageRoute(
          builder: (_) => const SupplierHomeScreen(),
        );
      
      case supplierOrders:
        return MaterialPageRoute(
          builder: (_) => const SupplierOrdersListScreen(),
        );
      
      case supplierCreateOrder:
        return MaterialPageRoute(
          builder: (_) => const CreateOrderScreen(),
        );
      
      case supplierCanceled:
        return MaterialPageRoute(
          builder: (_) => const SupplierCanceledOrdersScreen(),
        );
      
      case supplierPayments:
        return MaterialPageRoute(
          builder: (_) => const SupplierPaymentsScreen(),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}

