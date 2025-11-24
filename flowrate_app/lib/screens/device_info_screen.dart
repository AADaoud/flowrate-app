import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF12142A), Color(0xFF0E101C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Info',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'BLE connection details',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: dev == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No device connected',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connect to a device to view details',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Device Overview Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2196F3).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.bluetooth_connected,
                                            size: 28,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Connected Device',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                dev.name.isEmpty ? 'Unnamed ESP32' : dev.name,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _InfoRow(
                                      icon: Icons.fingerprint,
                                      label: 'Device ID',
                                      value: dev.id,
                                      onCopy: () => _copyToClipboard(context, dev.id),
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      icon: Icons.signal_cellular_alt,
                                      label: 'Signal Strength',
                                      value: '${ble.lastRssi ?? 0} dBm',
                                      valueColor: _getRssiColor(ble.lastRssi ?? 0),
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      icon: Icons.battery_charging_full,
                                      label: 'Battery Level',
                                      value: '${battery ?? 0}%',
                                      valueColor: _getBatteryColor(battery ?? 0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Protocol Details Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.api,
                                          size: 20,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'BLE Protocol',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _ProtocolItem(
                                      label: 'Service UUID',
                                      value: '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
                                      onCopy: () => _copyToClipboard(
                                        context,
                                        '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _ProtocolItem(
                                      label: 'Characteristic UUID',
                                      value: '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
                                      onCopy: () => _copyToClipboard(
                                        context,
                                        '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Payload Format Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.code,
                                          size: 20,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Payload Format',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Compressed JSON (<20 bytes)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              '{"v":<velocity_cm_per_s>,"b":<battery_%>}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'monospace',
                                                color: Color(0xFF4CAF50),
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              size: 18,
                                              color: Colors.white.withOpacity(0.6),
                                            ),
                                            onPressed: () => _copyToClipboard(
                                              context,
                                              '{"v":<velocity_cm_per_s>,"b":<battery_%>}',
                                            ),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Tip Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFF9800).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 20,
                                      color: const Color(0xFFFF9800).withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auto-reconnect Tip',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFFF9800).withOpacity(0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Keep the device advertising as "ESP32-Flow" or with the service UUID above to enable automatic reconnection.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withOpacity(0.8),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white.withOpacity(0.1),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF4CAF50);
    if (rssi >= -75) return const Color(0xFFFF9800);
    return const Color(0xFFFF5722);
  }

  Color _getBatteryColor(int battery) {
    if (battery >= 60) return const Color(0xFF4CAF50);
    if (battery >= 30) return const Color(0xFFFF9800);
    return const Color(0xFFFF5722);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: Icon(
              Icons.copy,
              size: 18,
              color: Colors.white.withOpacity(0.5),
            ),
            onPressed: onCopy,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
      ],
    );
  }
}

class _ProtocolItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _ProtocolItem({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF2196F3),
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  onPressed: onCopy,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}