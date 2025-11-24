import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';
import '../models/velocity_sample.dart';
import 'ble_service.dart';
import 'velocity_filter.dart';

class FlowController extends ChangeNotifier {
  FlowController(this.ble) {
    _statusSub = ble.statusStream.listen((s) {
      status = s;
      notifyListeners();
    });

    _readingSub = ble.readingStream.listen((reading) {
      latest = reading;
      _lastReadingReceived = DateTime.now();

      if (loggingEnabled) {
        final filtered = _filter.addSample(reading.velocity);
        _history.add(VelocitySample(filtered));
        if (_history.length > maxHistory) {
          _history.removeAt(0);
        }
      }

      notifyListeners();
    });
  }

  final BleVelocityService ble;
  final VelocityFilter _filter = VelocityFilter(windowSize: 6);

  AppBleStatus status =
      const AppBleStatus(AppBleStage.idle, 'Waiting to start BLE');
  FlowReading? latest;
  bool loggingEnabled = true;
  bool devMode = false;
  bool hapticsEnabled = true;
  bool soundEnabled = false;
  int maxHistory = 600;

  final List<VelocitySample> _history = [];
  List<VelocitySample> get history => List.unmodifiable(_history);

  DateTime? _lastReadingReceived;
  DateTime? get lastReadingReceived => _lastReadingReceived;

  StreamSubscription<AppBleStatus>? _statusSub;
  StreamSubscription<FlowReading>? _readingSub;

  void startBle() => ble.startScan();

  void toggleLogging(bool value) {
    loggingEnabled = value;
    if (!value) _history.clear();
    notifyListeners();
  }

  void setDevMode(bool value) {
    devMode = value;
    notifyListeners();
  }

  void setHaptics(bool value) {
    hapticsEnabled = value;
    notifyListeners();
  }

  void setSound(bool value) {
    soundEnabled = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _readingSub?.cancel();
    ble.dispose();
    super.dispose();
  }
}
