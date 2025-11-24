import 'dart:convert';

class FlowReading {
  final double velocity;
  final int battery;
  final int? rssi;
  final DateTime timestamp;
  final String raw;

  FlowReading({
    required this.velocity,
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
    final velocityValue = (map['v'] ?? map['velocity'] ?? 0) as num;
    final batteryValue = (map['b'] ?? map['battery'] ?? 0) as num;

    return FlowReading(
      velocity: velocityValue.toDouble(),
      battery: batteryValue.toInt().clamp(0, 100),
      rssi: rssi,
      raw: raw.isNotEmpty ? raw : jsonEncode(map),
      timestamp: DateTime.now(),
    );
  }
}
