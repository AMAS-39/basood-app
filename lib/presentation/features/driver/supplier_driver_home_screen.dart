import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/driver_bottom_nav.dart';
import 'supplier_driver_orders_screen.dart';
import 'supplier_driver_returned_screen.dart';
import 'supplier_driver_payments_screen.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

class SupplierDriverHomeScreen extends ConsumerStatefulWidget {
  const SupplierDriverHomeScreen({super.key});

  @override
  ConsumerState<SupplierDriverHomeScreen> createState() =>
      _SupplierDriverHomeScreenState();
}

class _SupplierDriverHomeScreenState
    extends ConsumerState<SupplierDriverHomeScreen> {
  int _selectedBottomNavIndex = 0; // Dashboard

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section - Greeting & Profile
              _buildTopSection(
                context,
                authState.user?.name ?? 'Supplier Driver',
              ),
              const SizedBox(height: 24),

              // Status Bar
              _buildStatusBar(context),
              const SizedBox(height: 24),

              // Main Dashboard Cards
              _buildDashboardCards(context),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DriverBottomNav(
        selectedIndex: _selectedBottomNavIndex,
        onTap: (index) {
          setState(() => _selectedBottomNavIndex = index);
          _handleBottomNavTap(context, index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // QR Code scanning functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Scanner coming soon')),
          );
        },
        backgroundColor: Colors.teal[800],
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, String driverName) {
    return Row(
      children: [
        // Profile Avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.business, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),

        // Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                driverName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Notification Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal, Colors.teal.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusItem(
              context,
              'Today\'s Deliveries',
              '0', // This would come from API
              Icons.local_shipping,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _buildStatusItem(
              context,
              'Active Orders',
              '0', // This would come from API
              Icons.assignment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.9)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDashboardCards(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildDashboardCard(
          context,
          'Supplier Orders',
          '0', // This would come from API
          Icons.business_center,
          Colors.blue,
        ),
        _buildDashboardCard(
          context,
          'Returned Orders',
          '0', // This would come from API
          Icons.assignment_return,
          Colors.red,
        ),
        _buildDashboardCard(
          context,
          'Payments Received',
          '0', // This would come from API
          Icons.payment,
          Colors.green,
        ),
        _buildDashboardCard(
          context,
          'Weekly Deliveries',
          '0', // This would come from API
          Icons.timeline,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'View Supplier Orders',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SupplierDriverOrdersScreen(),
                    ),
                  );
                },
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Returned Orders',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SupplierDriverReturnedScreen(),
                    ),
                  );
                },
                isPrimary: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'View Payments',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SupplierDriverPaymentsScreen(),
                    ),
                  );
                },
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Scan QR Code',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR Scanner coming soon')),
                  );
                },
                isPrimary: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: // Dashboard
        // Already on dashboard
        break;
      case 1: // Orders
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SupplierDriverOrdersScreen(),
          ),
        );
        break;
      case 2: // History/Payments
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SupplierDriverPaymentsScreen(),
          ),
        );
        break;
      case 3: // Settings
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
  }
}
