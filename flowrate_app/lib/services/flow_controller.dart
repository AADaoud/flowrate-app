import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';
import '../models/velocity_sample.dart';
import 'ble_service.dart';
import 'calibration_service.dart';
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

      _calibration.addSample(reading.rawVoltage);
      _updateVelocityHistory();

      notifyListeners();
    });
  }

  final BleVelocityService ble;
  final VelocityFilter _filter = VelocityFilter(windowSize: 6);
  final CalibrationService _calibration = CalibrationService();

  AppBleStatus status =
      AppBleStatus(AppBleStage.idle, 'Waiting to start BLE');
  FlowReading? latest;
  double? _calibratedVelocity;

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

  CalibrationStatus get calibrationStatus => _calibration.status;
  double? get calibratedVelocity => _calibratedVelocity;

  void _updateVelocityHistory() {
    final sample = latest;
    if (sample == null) return;

    final velocity = _calibration.status.apply(sample.rawVoltage);
    _calibratedVelocity = velocity;

    if (loggingEnabled) {
      final filtered = _filter.addSample(
        velocity ?? sample.rawVoltage,
      );
      _history.add(VelocitySample(filtered));
      if (_history.length > maxHistory) {
        _history.removeAt(0);
      }
    }
  }

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

  void resetCalibration() {
    _calibration.reset();
    _calibratedVelocity = null;
    notifyListeners();
  }

  bool captureReference(double knownVelocity,
      {bool electricalReference = false}) {
    final success = _calibration.captureReference(knownVelocity,
        electricalReference: electricalReference);
    if (success && latest != null) {
      _calibratedVelocity =
          _calibration.status.apply(latest!.rawVoltage);
    }
    notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _readingSub?.cancel();
    ble.dispose();
    super.dispose();
  }
}
