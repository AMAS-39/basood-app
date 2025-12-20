import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onLogout;
  final String? title;

  const DashboardAppBar({
    super.key,
    this.onLogout,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.grid_view, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Icon(Icons.bookmark, color: Colors.grey[600]),
          const Spacer(),
          Text(
            title ?? AppStrings.home,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          if (onLogout != null)
            IconButton(
              icon: Icon(Icons.logout, color: Colors.grey[600]),
              onPressed: onLogout,
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
