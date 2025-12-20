import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/driver_bottom_nav.dart';
import 'driver_controller.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_screen.dart';
import 'customer_driver_pending_screen.dart';
import 'customer_driver_current_screen.dart';
import 'customer_driver_history_screen.dart';
import '../settings/settings_screen.dart';

class CustomerDriverHomeScreen extends ConsumerStatefulWidget {
  const CustomerDriverHomeScreen({super.key});

  @override
  ConsumerState<CustomerDriverHomeScreen> createState() =>
      _CustomerDriverHomeScreenState();
}

class _CustomerDriverHomeScreenState
    extends ConsumerState<CustomerDriverHomeScreen> {
  int _selectedBottomNavIndex = 0; // Dashboard

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverControllerProvider.notifier).loadPendingOrders();
      ref.read(driverControllerProvider.notifier).loadCurrentOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverControllerProvider);
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
              _buildTopSection(context, authState.user?.name ?? 'Driver'),
              const SizedBox(height: 24),

              // Status Bar
              _buildStatusBar(context, driverState),
              const SizedBox(height: 24),

              // Main Dashboard Cards
              _buildDashboardCards(context, driverState),
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
        backgroundColor: Colors.blue[800],
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
            color: Colors.blue[800],
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blue[800]!.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
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

  Widget _buildStatusBar(BuildContext context, driverState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[800]!, Colors.blue[800]!.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[800]!.withOpacity(0.3),
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
              driverState.currentOrders.length.toString(),
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

  Widget _buildDashboardCards(BuildContext context, driverState) {
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
          'Pending Orders',
          driverState.pendingOrders.length.toString(),
          Icons.pending_actions,
          Colors.orange,
        ),
        _buildDashboardCard(
          context,
          'Current Deliveries',
          driverState.currentOrders.length.toString(),
          Icons.local_shipping,
          Colors.teal,
        ),
        _buildDashboardCard(
          context,
          'Delivered Orders',
          '0', // This would come from API
          Icons.check_circle,
          Colors.green,
        ),
        _buildDashboardCard(
          context,
          'Postponed Orders',
          '0', // This would come from API
          Icons.schedule,
          Colors.red,
        ),
        _buildDashboardCard(
          context,
          'Amount Changes',
          '0', // This would come from API
          Icons.edit,
          Colors.deepOrange,
        ),
        _buildDashboardCard(
          context,
          'Weekly Trips',
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
                text: 'View Pending Orders',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerDriverPendingScreen(),
                    ),
                  );
                },
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Current Orders',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerDriverCurrentScreen(),
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
                text: 'Delivery History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerDriverHistoryScreen(),
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
            builder: (context) => const CustomerDriverPendingScreen(),
          ),
        );
        break;
      case 2: // History
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerDriverHistoryScreen(),
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
