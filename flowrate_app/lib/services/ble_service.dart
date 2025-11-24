import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';

/// BLE glue for the ESP32 flow sensor.
///
/// Responsibilities:
/// - Scans for the advertised device name or service UUID.
/// - Handles fragmented JSON packets under 20 bytes and emits [FlowReading].
/// - Provides status updates for the UI.
class BleVelocityService {
  BleVelocityService();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final serviceUuid =
      Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final charUuid =
      Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  DiscoveredDevice? device;
  int? lastRssi;

  final _statusController = StreamController<AppBleStatus>.broadcast();
  Stream<AppBleStatus> get statusStream => _statusController.stream;

  final _readingController = StreamController<FlowReading>.broadcast();
  Stream<FlowReading> get readingStream => _readingController.stream;

  final _velocityController = StreamController<double>.broadcast();
  Stream<double> get velocityStream => _velocityController.stream;

  final _batteryController = StreamController<int>.broadcast();
  Stream<int> get batteryStream => _batteryController.stream;

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<int>? _rssiSub;

  final StringBuffer _jsonBuffer = StringBuffer();
  int _retryCount = 0;
  bool _disposed = false;

  // ================================================================
  // Public API
  // ================================================================
  void startScan() {
    if (_disposed) return;
    _scanSub?.cancel();
    _emit(const AppBleStatus(AppBleStage.scanning, "Scanning for ESP32-Flow"));

    _scanSub = _ble
        .scanForDevices(
          withServices: [serviceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen((dev) {
      final matchesName = dev.name.trim().toLowerCase() == 'esp32-flow';
      final exposesService = dev.serviceUuids.contains(serviceUuid);

      if (matchesName || exposesService) {
        device = dev;
        lastRssi = dev.rssi;
        _scanSub?.cancel();
        _connect();
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Scan error: $e"));
    });
  }

  void disconnect() {
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiSub?.cancel();
    _emit(const AppBleStatus(AppBleStage.disconnected, "Disconnected"));
  }

  // ================================================================
  // Connection + subscription
  // ================================================================
  void _connect() {
    final target = device;
    if (target == null || _disposed) return;

    _emit(const AppBleStatus(AppBleStage.connecting, "Connecting"));

    _connSub = _ble
        .connectToDevice(
      id: target.id,
      connectionTimeout: const Duration(seconds: 8),
      servicesWithCharacteristicsToDiscover: {
        serviceUuid: [charUuid],
      },
    )
        .listen((update) {
      switch (update.connectionState) {
        case DeviceConnectionState.connected:
          _emit(const AppBleStatus(AppBleStage.connected, "Connected"));
          _retryCount = 0;
          _startRssiStream();
          _subscribe();
          break;
        case DeviceConnectionState.disconnected:
          _emit(const AppBleStatus(AppBleStage.disconnected, "Disconnected"));
          _scheduleReconnect();
          break;
        default:
          break;
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Connect error: $e"));
      _scheduleReconnect();
    });
  }

  void _subscribe() {
    final target = device;
    if (target == null || _disposed) return;

    final q = QualifiedCharacteristic(
      deviceId: target.id,
      serviceId: serviceUuid,
      characteristicId: charUuid,
    );

    _emit(const AppBleStatus(AppBleStage.notifying, "Streaming live data"));

    _notifySub = _ble.subscribeToCharacteristic(q).listen((bytes) {
      _handleIncomingBytes(bytes);
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Notify error: $e"));
      _scheduleReconnect();
    });
  }

  void _startRssiStream() {
    final target = device;
    if (target == null) return;
    _rssiSub?.cancel();
    _rssiSub = _ble
        .rssiStream(deviceId: target.id)
        .listen((value) => lastRssi = value, onError: (_) {});
  }

  // ================================================================
  // Payload handling
  // ================================================================
  void _handleIncomingBytes(List<int> bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _jsonBuffer.write(chunk);

    // Keep buffer bounded to avoid runaway memory if malformed data arrives
    if (_jsonBuffer.length > 200) {
      final content = _jsonBuffer.toString();
      _jsonBuffer.clear();
      _jsonBuffer.write(content.substring(content.length - 200));
    }

    while (true) {
      final content = _jsonBuffer.toString();
      final start = content.indexOf('{');
      final end = content.indexOf('}', start + 1);

      if (start != -1 && end != -1 && end > start) {
        final jsonStr = content.substring(start, end + 1);
        _jsonBuffer.clear();
        _jsonBuffer.write(content.substring(end + 1));

        try {
          final reading = FlowReading.fromPayload(jsonStr, rssi: lastRssi);
          _readingController.add(reading);
          _velocityController.add(reading.velocity);
          _batteryController.add(reading.battery);
        } catch (e) {
          // Skip malformed fragment but keep buffer for future merges
          _emit(AppBleStatus(AppBleStage.error, "Payload error: $e"));
        }
      } else {
        break;
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _scanSub?.cancel();
    _notifySub?.cancel();
    _rssiSub?.cancel();

    final backoff = Duration(seconds: 2 + (_retryCount * 2).clamp(0, 8));
    _retryCount++;
    Future.delayed(backoff, () {
      if (!_disposed) {
        startScan();
      }
    });
  }

  void _emit(AppBleStatus s) {
    if (_disposed) return;
    _statusController.add(s);
  }

  // ================================================================
  // CLEANUP
  // ================================================================
  void dispose() {
    _disposed = true;
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiSub?.cancel();
    _statusController.close();
    _readingController.close();
    _velocityController.close();
    _batteryController.close();
  }
}
