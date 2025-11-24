import 'package:flutter/material.dart';

import '../models/app_ble_status.dart';

class BleStatusBar extends StatelessWidget {
  final AppBleStatus status;

  const BleStatusBar({super.key, required this.status});

  Color _bgColor() {
    switch (status.stage) {
      case AppBleStage.connected:
      case AppBleStage.notifying:
        return Colors.green.withOpacity(0.18);
      case AppBleStage.scanning:
      case AppBleStage.connecting:
        return Colors.orange.withOpacity(0.18);
      case AppBleStage.error:
        return Colors.redAccent.withOpacity(0.18);
      case AppBleStage.disconnected:
      case AppBleStage.idle:
      default:
        return Colors.white.withOpacity(0.06);
    }
  }

  IconData _icon() {
    switch (status.stage) {
      case AppBleStage.connected:
        return Icons.check_circle;
      case AppBleStage.notifying:
        return Icons.waves;
      case AppBleStage.scanning:
        return Icons.search;
      case AppBleStage.connecting:
        return Icons.bluetooth_connected;
      case AppBleStage.error:
        return Icons.error_outline;
      default:
        return Icons.bluetooth_disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              status.message,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
