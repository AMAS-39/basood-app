import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String number;
  final String title;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final String? badgeNumber;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.number,
    required this.title,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.badgeNumber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: textColor,
                size: 24,
              ),
              const SizedBox(width: 12),
            ] else ...[
              Text(
                number,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            if (badgeNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.yellow[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeNumber!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}
