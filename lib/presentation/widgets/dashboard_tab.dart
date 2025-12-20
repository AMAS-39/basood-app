import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const DashboardTab({
    super.key,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey[300]!,
                width: isActive ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[600],
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
