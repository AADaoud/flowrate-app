import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/app_ble_status.dart';

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

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  /// JSON packets may arrive split → buffer until valid JSON appears
  String _jsonBuffer = "";

  // ================================================================
  // START SCAN
  // ================================================================
  void start() {
    _emit(const AppBleStatus(
        AppBleStage.scanning, "Scanning for ESP32-Flow..."));

    _scanSub = _ble
        .scanForDevices(withServices: [])
        .listen((dev) {
      if (dev.name == "ESP32-Flow") {
        device = dev;
        lastRssi = dev.rssi;
        _scanSub?.cancel();
        _connect();
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Scan error: $e"));
    });
  }

  // ================================================================
  // CONNECT
  // ================================================================
  void _connect() {
    if (device == null) return;

    _emit(const AppBleStatus(AppBleStage.connecting, "Connecting..."));

    _connSub = _ble
        .connectToDevice(
      id: device!.id,
      connectionTimeout: const Duration(seconds: 6),
    )
        .listen((update) {
      switch (update.connectionState) {
        case DeviceConnectionState.connected:
          _emit(const AppBleStatus(AppBleStage.connected, "Connected"));
          _subscribe();
          break;

        case DeviceConnectionState.disconnected:
          _emit(const AppBleStatus(
              AppBleStage.disconnected, "Disconnected"));
          Future.delayed(const Duration(seconds: 1), start);
          break;

        default:
          break;
      }
    }, onError: (e) {
      _emit(AppBleStatus(AppBleStage.error, "Connect error: $e"));
    });
  }

  // ================================================================
  // SUBSCRIBE TO NUS NOTIFY CHARACTERISTIC
  // ================================================================
  void _subscribe() {
    if (device == null) return;

    final q = QualifiedCharacteristic(
      deviceId: device!.id,
      serviceId: serviceUuid,
      characteristicId: charUuid,
    );

    _emit(const AppBleStatus(
        AppBleStage.notifying, "Receiving data..."));

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
  print("BYTES: $bytes");

  final part = utf8.decode(bytes, allowMalformed: true);
  print("STRING CHUNK: $part");

  _jsonBuffer += part;

  while (true) {
    final start = _jsonBuffer.indexOf('{');
    final end = _jsonBuffer.indexOf('}');

    if (start != -1 && end != -1 && end > start) {
      final jsonStr = _jsonBuffer.substring(start, end + 1);
      print("JSON FRAGMENT: $jsonStr");

      _jsonBuffer = _jsonBuffer.substring(end + 1);

      try {
        final map = jsonDecode(jsonStr);
        print("PARSED JSON: $map");

        _velocityController.add((map["v"] as num).toDouble());
        _batteryController.add((map["b"] as num).toInt());

      } catch (e) {
        print("JSON PARSE ERROR: $e");
        print("BUFFER AFTER ERROR: $_jsonBuffer");
      }

    } else {
      break;
    }
  }
}


  void _emit(AppBleStatus s) {
    _statusController.add(s);
  }

  // ================================================================
  // CLEANUP
  // ================================================================
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _statusController.close();
    _velocityController.close();
    _batteryController.close();
  }
}
