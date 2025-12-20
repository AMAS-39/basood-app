import 'package:flutter/material.dart';

class DashboardFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const DashboardFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.black,
      tooltip: tooltip,
      heroTag: tooltip ?? icon.toString(), // Unique hero tag
      child: Icon(icon, color: Colors.white),
    );
  }
}
