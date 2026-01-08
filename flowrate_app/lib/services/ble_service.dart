import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';

/// BLE glue for the ESP32 flow sensor.
///
/// Features:
/// - Scans for ESP32-Flow device by advertised name or service UUID.
/// - Handles BLE <20-byte JSON packets safely and reassembles full messages.
/// - Emits FlowReading objects for raw voltage + battery.
/// - Provides clean status stream for UI.
/// - Performs periodic RSSI polling (since rssiStream() was removed).
/// - Automatic reconnection with exponential backoff.
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

  final _batteryController = StreamController<int>.broadcast();
  Stream<int> get batteryStream => _batteryController.stream;

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  Timer? _rssiTimer;

  final StringBuffer _jsonBuffer = StringBuffer();
  int _retry = 0;
  bool _disposed = false;

  // ================================================================
  // PUBLIC API
  // ================================================================
  void startScan() {
    if (_disposed) return;

    _scanSub?.cancel();
    _emit(AppBleStatus(AppBleStage.scanning, "Scanning for ESP32-Flow…"));

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
    _rssiTimer?.cancel();
    _emit(AppBleStatus(AppBleStage.disconnected, "Disconnected"));
  }

  // ================================================================
  // CONNECTION LOGIC
  // ================================================================
  void _connect() {
    final target = device;
    if (target == null || _disposed) return;

    _emit(AppBleStatus(AppBleStage.connecting, "Connecting…"));

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
          _emit(AppBleStatus(AppBleStage.connected, "Connected"));
          _retry = 0;
          _startRssiPolling();
          _subscribe();
          break;

        case DeviceConnectionState.disconnected:
          _emit(AppBleStatus(AppBleStage.disconnected, "Disconnected"));
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

  // ================================================================
  // SUBSCRIBE TO STREAMING DATA
  // ================================================================
  void _subscribe() {
    final target = device;
    if (target == null || _disposed) return;

    final q = QualifiedCharacteristic(
      deviceId: target.id,
      serviceId: serviceUuid,
      characteristicId: charUuid,
    );

    _emit(AppBleStatus(AppBleStage.notifying, "Receiving live data…"));

    _notifySub = _ble.subscribeToCharacteristic(q).listen((bytes) {
      _handleIncoming(bytes);
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Notify error: $e"));
      _scheduleReconnect();
    });
  }

  // ================================================================
  // CLEAN RSSI POLLING (REPLACEMENT FOR REMOVED rssiStream())
  // ================================================================
  void _startRssiPolling() {
    final target = device;
    if (target == null) return;

    _rssiTimer?.cancel();

    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final scan = await _ble
            .scanForDevices(
              withServices: [],
              scanMode: ScanMode.lowPower,
              requireLocationServicesEnabled: false,
            )
            .timeout(const Duration(milliseconds: 300))
            .first;

        if (scan.id == target.id) {
          lastRssi = scan.rssi;
        }
      } catch (_) {
        // Timeout or no scan results — OK
      }
    });
  }

  void reset() {
    // Stop reconnect loops
    _disposed = false;

    // Cancel all activity
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiTimer?.cancel();

    // Reset state
    device = null;
    lastRssi = null;
    _retry = 0;
    _jsonBuffer.clear();

    // Inform UI
    _emit(AppBleStatus(AppBleStage.idle, "Reset"));

    // Start clean scan
    Future.delayed(const Duration(milliseconds: 150), startScan);
  }


  // ================================================================
  // PAYLOAD HANDLING (FRAGMENTED JSON <20 bytes)
  // ================================================================
  void _handleIncoming(List<int> bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _jsonBuffer.write(chunk);

    // Avoid unlimited memory growth
    if (_jsonBuffer.length > 200) {
      final text = _jsonBuffer.toString();
      _jsonBuffer.clear();
      _jsonBuffer.write(text.substring(text.length - 200));
    }

    while (true) {
      final text = _jsonBuffer.toString();
      final start = text.indexOf('{');
      final end = text.indexOf('}', start + 1);

      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);

        // Remove extracted JSON from buffer
        _jsonBuffer.clear();
        _jsonBuffer.write(text.substring(end + 1));

        try {
          final reading = FlowReading.fromPayload(jsonStr, rssi: lastRssi);
          if (kDebugMode) {
            debugPrint(
                '[BLE] payload parsed v=${reading.rawVoltage}V b=${reading.battery}% rssi=$lastRssi');
          }
          _readingController.add(reading);
          _batteryController.add(reading.battery);
        } catch (e) {
          _emit(AppBleStatus(AppBleStage.error, "Payload error: $e"));
        }
      } else {
        break;
      }
    }
  }

  // ================================================================
  // RECONNECT LOGIC
  // ================================================================
  void _scheduleReconnect() {
    if (_disposed) return;

    _scanSub?.cancel();
    _notifySub?.cancel();
    _rssiTimer?.cancel();

    final delay = Duration(seconds: 2 + (_retry * 2).clamp(0, 8));
    _retry++;

    Future.delayed(delay, () {
      if (!_disposed) startScan();
    });
  }

  // ================================================================
  // HELPERS
  // ================================================================
  void _emit(AppBleStatus s) {
    if (!_disposed) _statusController.add(s);
  }

  // ================================================================
  // CLEANUP
  // ================================================================
  void dispose() {
    _disposed = true;

    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiTimer?.cancel();

    _statusController.close();
    _readingController.close();
    _batteryController.close();
  }
}
