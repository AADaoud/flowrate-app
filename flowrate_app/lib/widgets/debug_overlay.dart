import 'package:flutter/material.dart';

class DebugOverlay extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final double velocity;
  final int? battery;
  final String lastStatus;
  final String error;

  const DebugOverlay({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.velocity,
    required this.battery,
    required this.lastStatus,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white10,
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
                Text('Velocity: ${velocity.toStringAsFixed(2)} cm/s'),
                Text('Battery: ${battery ?? 0}%'),
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
