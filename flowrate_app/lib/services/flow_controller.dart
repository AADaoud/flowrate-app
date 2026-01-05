import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';
import '../models/setup_profile.dart';
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

      _calibration.addSample(activeProfile?.id, reading.rawVoltage);
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
  SetupProfile? activeProfile;
  int? lastBattery;
  final List<SetupProfile> profiles = [];

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

  CalibrationStatus get calibrationStatus =>
      _calibration.statusForProfile(activeProfile?.id);
  double? get calibratedVelocity => _calibratedVelocity;
  bool get hasProfile => activeProfile != null;
  bool get calibrationMatchesProfile =>
      hasProfile &&
      calibrationStatus.profileId == activeProfile!.id &&
      calibrationStatus.isOperational;

  void _updateVelocityHistory() {
    final sample = latest;
    if (sample == null) return;

    final velocity = _calibration.apply(activeProfile?.id, sample.rawVoltage);
    _calibratedVelocity = velocity;
    lastBattery = sample.battery;

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
    _calibration.resetProfile(activeProfile?.id);
    _calibratedVelocity = null;
    notifyListeners();
  }

  bool captureReference(double knownVelocity,
      {bool electricalReference = false}) {
    final success = _calibration.captureReference(
      activeProfile?.id,
      knownVelocity,
      electricalReference: electricalReference,
    );
    if (success && latest != null) {
      _calibratedVelocity =
          _calibration.apply(activeProfile?.id, latest!.rawVoltage);
    }
    notifyListeners();
    return success;
  }

  void addProfile(SetupProfile profile) {
    profiles.add(profile);
    activeProfile = profile;
    _calibratedVelocity = null;
    _calibration.resetProfile(profile.id);
    notifyListeners();
  }

  void selectProfile(String profileId) {
    final found = profiles.where((p) => p.id == profileId);
    if (found.isEmpty) return;
    activeProfile = found.first;
    _calibratedVelocity = null;
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
