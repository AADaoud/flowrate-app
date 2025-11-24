import 'package:flutter/material.dart';
import '../models/app_ble_status.dart';

class BleStatusBar extends StatelessWidget {
  final AppBleStatus status;

  const BleStatusBar({super.key, required this.status});

  Color _bgColor() {
    switch (status.stage) {
      case AppBleStage.connected:
        return Colors.green.withOpacity(0.3);
      case AppBleStage.scanning:
      case AppBleStage.connecting:
        return Colors.orange.withOpacity(0.3);
      case AppBleStage.error:
        return Colors.red.withOpacity(0.3);
      case AppBleStage.disconnected:
      case AppBleStage.idle:
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.message,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
