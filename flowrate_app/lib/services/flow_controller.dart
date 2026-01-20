import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
      if (kDebugMode) {
        debugPrint(
            '[FlowController] reading v=${reading.rawVoltage}V b=${reading.battery}% profile=${activeProfile?.id ?? "none"}');
      }

      final adjustedVoltage = _applyVoltageSettings(reading.rawVoltage);
      _adjustedVoltage = adjustedVoltage;
      _calibration.addSample(
        activeProfile?.id,
        adjustedVoltage,
        requireReference: requireReference,
      );
      _updateVelocityHistory(adjustedVoltage);

      notifyListeners();
    });

    _batterySub = ble.batteryStream.listen((batt) {
      lastBattery = batt;
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
  bool requireReference = true;
  double voltageMin = 0.0;
  double voltageMax = 2.24;
  double velocityMin = 24.0;
  double velocityMax = 40.0;
  bool invertPolarity = false;

  final List<VelocitySample> _history = [];
  List<VelocitySample> get history => List.unmodifiable(_history);
  double? _adjustedVoltage;
  double? get adjustedVoltage => _adjustedVoltage;

  DateTime? _lastReadingReceived;
  DateTime? get lastReadingReceived => _lastReadingReceived;

  StreamSubscription<AppBleStatus>? _statusSub;
  StreamSubscription<FlowReading>? _readingSub;
  StreamSubscription<int>? _batterySub;

  CalibrationStatus get calibrationStatus =>
      _calibration.statusForProfile(activeProfile?.id);
  double? get calibratedVelocity => _calibratedVelocity;
  bool get hasProfile => activeProfile != null;
  bool get calibrationMatchesProfile =>
      hasProfile &&
      calibrationStatus.profileId == activeProfile!.id &&
      calibrationStatus.isOperational;

  void _updateVelocityHistory(double adjustedVoltage) {
    final sample = latest;
    if (sample == null) return;

    final velocity = _calibration.apply(activeProfile?.id, adjustedVoltage);
    _calibratedVelocity = velocity == null ? null : _clampVelocity(velocity);
    lastBattery = sample.battery;

    if (loggingEnabled) {
      final filtered = _filter.addSample(
        _calibratedVelocity ?? adjustedVoltage,
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

  void setVoltageRange({required double min, required double max}) {
    final normalized = _normalizeRange(min, max);
    voltageMin = normalized.$1;
    voltageMax = normalized.$2;
    if (latest != null) {
      final adjusted = _applyVoltageSettings(latest!.rawVoltage);
      _adjustedVoltage = adjusted;
      final recalculated = _calibration.apply(activeProfile?.id, adjusted);
      _calibratedVelocity =
          recalculated == null ? null : _clampVelocity(recalculated);
    }
    notifyListeners();
  }

  void setVelocityRange({required double min, required double max}) {
    final normalized = _normalizeRange(min, max);
    velocityMin = normalized.$1;
    velocityMax = normalized.$2;
    _calibration.updateVelocityRange(velocityMin, velocityMax);
    if (_calibratedVelocity != null) {
      _calibratedVelocity = _clampVelocity(_calibratedVelocity!);
    }
    notifyListeners();
  }

  void setInvertPolarity(bool value) {
    invertPolarity = value;
    if (latest != null) {
      final adjusted = _applyVoltageSettings(latest!.rawVoltage);
      _adjustedVoltage = adjusted;
      final recalculated = _calibration.apply(activeProfile?.id, adjusted);
      _calibratedVelocity =
          recalculated == null ? null : _clampVelocity(recalculated);
    }
    notifyListeners();
  }

  void setRequireReference(bool value) {
    requireReference = value;
    _calibration.resetProfile(activeProfile?.id);
    _calibratedVelocity = null;
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
      final adjusted = _applyVoltageSettings(latest!.rawVoltage);
      _adjustedVoltage = adjusted;
      final recalculated = _calibration.apply(activeProfile?.id, adjusted);
      _calibratedVelocity =
          recalculated == null ? null : _clampVelocity(recalculated);
    }
    notifyListeners();
    return success;
  }

  void addProfile(SetupProfile profile) {
    profiles.add(profile);
    activeProfile = profile;
    _calibratedVelocity = null;
    _calibration.registerProfile(profile);
    _calibration.resetProfile(profile.id);
    notifyListeners();
  }

  void selectProfile(String profileId) {
    final found = profiles.where((p) => p.id == profileId);
    if (found.isEmpty) return;
    activeProfile = found.first;
    _calibration.registerProfile(found.first);
    _calibratedVelocity = null;
    notifyListeners();
  }

  double _applyVoltageSettings(double rawVoltage) {
    final polarityAdjusted = invertPolarity ? -rawVoltage : rawVoltage;
    return polarityAdjusted.clamp(voltageMin, voltageMax).toDouble();
  }

  double _clampVelocity(double velocity) {
    return velocity.clamp(velocityMin, velocityMax).toDouble();
  }

  (double, double) _normalizeRange(double min, double max) {
    if (min <= max) return (min, max);
    return (max, min);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _readingSub?.cancel();
    _batterySub?.cancel();
    ble.dispose();
    super.dispose();
  }
}
