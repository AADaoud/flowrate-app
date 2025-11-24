class TelemetryReading {
  final double velocity;
  final int battery;
  final DateTime timestamp;
  final int? rssi;

  const TelemetryReading({
    required this.velocity,
    required this.battery,
    required this.timestamp,
    this.rssi,
  });
}
