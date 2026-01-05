import 'package:flutter/material.dart';

class DebugOverlay extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final double rawVoltage;
  final double? velocity;
  final bool calibrated;
  final int? battery;
  final int? rssi;
  final String lastStatus;
  final String error;

  const DebugOverlay({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.rawVoltage,
    required this.velocity,
    required this.calibrated,
    required this.battery,
    required this.rssi,
    required this.lastStatus,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.84),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Developer / Debug Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Device: $deviceName'),
                Text('ID: $deviceId'),
                Text(
                    'Velocity: ${calibrated && velocity != null ? velocity!.toStringAsFixed(2) : "LOCKED"}'),
                Text('Raw: ${rawVoltage.toStringAsFixed(4)} V'),
                Text('Battery: ${battery ?? 0}%'),
                Text('RSSI: ${rssi ?? 0} dBm'),
                Text('Status: $lastStatus'),
                Text('Error: ${error.isEmpty ? "None" : error}'),
                const SizedBox(height: 12),
                const Text(
                  '(Tap anywhere to close)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
