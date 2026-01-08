import 'dart:convert';

class FlowReading {
  static const double voltageScaleFactor = 8.0;
  final double rawVoltage;
  final int battery;
  final int? rssi;
  final DateTime timestamp;
  final String raw;

  FlowReading({
    required this.rawVoltage,
    required this.battery,
    this.rssi,
    required this.timestamp,
    required this.raw,
  });

  factory FlowReading.fromPayload(String payload, {int? rssi}) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return FlowReading.fromMap(map, raw: payload, rssi: rssi);
  }

  factory FlowReading.fromMap(Map<String, dynamic> map,
      {String raw = '', int? rssi}) {
    final voltageValue = (map['v'] ?? map['voltage'] ?? map['velocity'] ?? 0)
        as num;
    final batteryValue = (map['b'] ?? map['battery'] ?? 0) as num;

    return FlowReading(
      rawVoltage: voltageValue.toDouble() * voltageScaleFactor,
      battery: batteryValue.toInt().clamp(0, 100),
      rssi: rssi,
      raw: raw.isNotEmpty ? raw : jsonEncode(map),
      timestamp: DateTime.now(),
    );
  }
}
