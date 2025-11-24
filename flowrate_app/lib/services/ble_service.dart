import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/app_ble_status.dart';
import '../models/telemetry_reading.dart';

/// BLE helper focused on reliability and compact JSON parsing.
///
/// Keeps a running buffer to handle fragmented packets (<20 bytes) and will
/// automatically rescan/reconnect with small backoff to avoid reconnect storms.
class BleVelocityService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final serviceUuid =
      Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final charUuid =
      Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  DiscoveredDevice? device;
  int? lastRssi;

  final _statusController = StreamController<AppBleStatus>.broadcast();
  Stream<AppBleStatus> get statusStream => _statusController.stream;

  final _velocityController = StreamController<double>.broadcast();
  Stream<double> get velocityStream => _velocityController.stream;

  final _batteryController = StreamController<int>.broadcast();
  Stream<int> get batteryStream => _batteryController.stream;

  final _telemetryController = StreamController<TelemetryReading>.broadcast();
  Stream<TelemetryReading> get telemetryStream => _telemetryController.stream;

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// JSON packets may arrive split → buffer until valid JSON appears
  String _jsonBuffer = "";

  bool _isShuttingDown = false;

  // ================================================================
  // START SCAN
  // ================================================================
  void start() {
    _isShuttingDown = false;
    _emit(const AppBleStatus(
        AppBleStage.scanning, "Scanning for ESP32-Flow..."));

    _scanSub?.cancel();
    _scanSub = _ble
        .scanForDevices(withServices: [serviceUuid])
        .listen((dev) {
      if (dev.name == "ESP32-Flow") {
        device = dev;
        lastRssi = dev.rssi;
        _scanSub?.cancel();
        _connect();
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Scan error: $e"));
      _retryWithBackoff();
    });
  }

  // ================================================================
  // CONNECT
  // ================================================================
  void _connect() {
    if (device == null || _isShuttingDown) return;

    _emit(AppBleStatus(
        AppBleStage.connecting, "Connecting to ${device!.name}..."));

    _connSub?.cancel();
    _connSub = _ble
        .connectToDevice(
      id: device!.id,
      connectionTimeout: const Duration(seconds: 8),
    )
        .listen((update) {
      switch (update.connectionState) {
        case DeviceConnectionState.connected:
          _reconnectAttempts = 0;
          _emit(const AppBleStatus(AppBleStage.connected, "Connected"));
          _subscribe();
          break;

        case DeviceConnectionState.disconnected:
          _emit(const AppBleStatus(
              AppBleStage.disconnected, "Disconnected"));
          _retryWithBackoff();
          break;

        default:
          break;
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Connect error: $e"));
      _retryWithBackoff();
    });
  }

  // ================================================================
  // SUBSCRIBE TO NUS NOTIFY CHARACTERISTIC
  // ================================================================
  void _subscribe() {
    if (device == null || _isShuttingDown) return;

    final q = QualifiedCharacteristic(
      deviceId: device!.id,
      serviceId: serviceUuid,
      characteristicId: charUuid,
    );

    _emit(const AppBleStatus(
        AppBleStage.notifying, "Receiving data..."));

    _notifySub?.cancel();
    _notifySub = _ble.subscribeToCharacteristic(q).listen((bytes) {
      _handleIncomingBytes(bytes);
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Notify error: $e"));
    });
  }

  // ================================================================
  // HANDLE JSON STREAM (supports fragmented BLE packets)
  // ================================================================
  void _handleIncomingBytes(List<int> bytes) {
    if (bytes.isEmpty) return;

    // Keep buffer small to avoid runaway memory usage on malformed streams.
    if (_jsonBuffer.length > 120) {
      _jsonBuffer = "";
    }

    final part = utf8.decode(bytes, allowMalformed: true);
    _jsonBuffer += part;

    while (true) {
      final start = _jsonBuffer.indexOf('{');
      final end = _jsonBuffer.indexOf('}');

      if (start != -1 && end != -1 && end > start) {
        final jsonStr = _jsonBuffer.substring(start, end + 1);
        _jsonBuffer = _jsonBuffer.substring(end + 1);

        try {
          final map = jsonDecode(jsonStr);
          final velocity = (map["v"] as num?)?.toDouble();
          final battery = (map["b"] as num?)?.toInt();

          if (velocity == null || battery == null) continue;

          final reading = TelemetryReading(
            velocity: velocity,
            battery: battery,
            timestamp: DateTime.now(),
            rssi: lastRssi,
          );

          _telemetryController.add(reading);
          _velocityController.add(velocity);
          _batteryController.add(battery);
        } catch (e) {
          if (kDebugMode) {
            print("JSON parse error: $e for chunk $jsonStr");
          }
        }
      } else {
        break;
      }
    }
  }

  void _retryWithBackoff() {
    if (_isShuttingDown) return;

    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 6);
    final delay = Duration(seconds: 1 * _reconnectAttempts);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, start);
  }

  void _emit(AppBleStatus s) {
    _statusController.add(s);
  }

  // ================================================================
  // CLEANUP
  // ================================================================
  void dispose() {
    _isShuttingDown = true;
    _reconnectTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _statusController.close();
    _velocityController.close();
    _batteryController.close();
    _telemetryController.close();
  }
}
