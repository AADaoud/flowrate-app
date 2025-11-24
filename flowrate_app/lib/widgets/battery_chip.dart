import 'package:flutter/material.dart';

class BatteryChip extends StatelessWidget {
  final int? battery;

  const BatteryChip({super.key, required this.battery});

  @override
  Widget build(BuildContext context) {
    final value = (battery ?? 0).clamp(0, 100);
    IconData icon;
    if (value >= 80) {
      icon = Icons.battery_full;
    } else if (value >= 50) {
      icon = Icons.battery_5_bar;
    } else if (value >= 20) {
      icon = Icons.battery_3_bar;
    } else {
      icon = Icons.battery_alert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text('$value%', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
