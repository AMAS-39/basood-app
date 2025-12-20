import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey[600],
      currentIndex: selectedIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.comment),
          label: AppStrings.comments,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.notifications),
          label: AppStrings.notificationsNav,
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.grid_view, color: Colors.white),
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.attach_money),
          label: AppStrings.cashReceiptsNav,
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home, color: Colors.white),
          ),
          label: AppStrings.homeNav,
        ),
      ],
    );
  }
}
