import 'package:flutter/material.dart';

class StatusUpdateModal extends StatelessWidget {
  final String orderCode;
  final Function(String) onStatusSelected;

  const StatusUpdateModal({
    super.key,
    required this.orderCode,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Update Status for $orderCode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildStatusOption(
            context,
            icon: Icons.local_shipping,
            color: Colors.green,
            title: 'Driver Pickup',
            status: 'DriverPickup',
          ),
          _buildStatusOption(
            context,
            icon: Icons.access_time,
            color: Colors.orange,
            title: 'Postponed',
            status: 'Postponed',
          ),
          _buildStatusOption(
            context,
            icon: Icons.cancel,
            color: Colors.red,
            title: 'Canceled',
            status: 'Canceled',
          ),
          _buildStatusOption(
            context,
            icon: Icons.warning,
            color: Colors.amber,
            title: 'Partial Canceled',
            status: 'PartialCanceled',
          ),
          _buildStatusOption(
            context,
            icon: Icons.check_circle,
            color: Colors.green,
            title: 'Delivered',
            status: 'Delivered',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String status,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        onStatusSelected(status);
      },
    );
  }
}
