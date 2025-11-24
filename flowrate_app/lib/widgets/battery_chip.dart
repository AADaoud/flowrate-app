import 'package:flutter/material.dart';

class BatteryChip extends StatelessWidget {
  final int? battery;

  const BatteryChip({super.key, required this.battery});

  @override
  Widget build(BuildContext context) {
    final value = (battery ?? 0).clamp(0, 100);
    IconData icon;
    Color tone;
    if (value >= 80) {
      icon = Icons.battery_full;
      tone = Colors.greenAccent;
    } else if (value >= 50) {
      icon = Icons.battery_5_bar;
      tone = Colors.lightGreenAccent;
    } else if (value >= 20) {
      icon = Icons.battery_3_bar;
      tone = Colors.amberAccent;
    } else {
      icon = Icons.battery_alert;
      tone = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            tone.withOpacity(0.18),
            Colors.white.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Text(
            '$value%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
