import 'package:flutter/material.dart';

import '../services/ble_service.dart';

class DeviceInfoScreen extends StatelessWidget {
  final BleVelocityService ble;
  final int? battery;

  const DeviceInfoScreen({
    super.key,
    required this.ble,
    required this.battery,
  });

  @override
  Widget build(BuildContext context) {
    final dev = ble.device;

    return Scaffold(
      appBar: AppBar(title: const Text('Device Info')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: dev == null
            ? const Center(
                child: Text('No device connected'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dev.name.isEmpty ? 'Unnamed ESP32' : dev.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('ID: ${dev.id}'),
                  const SizedBox(height: 8),
                  Text('RSSI (last seen): ${ble.lastRssi ?? 0} dBm'),
                  const SizedBox(height: 8),
                  Text('Battery: ${battery ?? 0}%'),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Protocol',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This device exposes a BLE service with:\n'
                    '• Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E\n'
                    '• Characteristic UUID: 6E400003-B5A3-F393-E0A9-E50E24DCCA9E\n',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Notification payload (JSON):\n'
                    '{ "velocity": <double>, "battery": <int 0-100> }',
                  ),
                ],
              ),
      ),
    );
  }
}
