import 'dart:math';
import '../models/setup_profile.dart';

enum CalibrationPhase {
  uncalibrated,
  profiling,
  waitingForReference,
  calibrated,
  unstable,
}

class CalibrationStatus {
  CalibrationStatus({
    required this.profileId,
    required this.phase,
    required this.sampleCount,
    required this.noise,
    required this.drift,
    required this.stabilityScore,
    required this.referenceIsElectrical,
    this.baseline,
    this.slope,
    this.intercept,
    this.referenceVelocity,
    this.referenceVoltage,
    this.message,
  });

  final String profileId;
  final CalibrationPhase phase;
  final int sampleCount;
  final double? baseline;
  final double noise;
  final double drift;
  final double? slope;
  final double? intercept;
  final double stabilityScore;
  final double? referenceVelocity;
  final double? referenceVoltage;
  final bool referenceIsElectrical;
  final String? message;

  bool get hasBaseline => baseline != null;
  bool get hasReference =>
      referenceVelocity != null && referenceVoltage != null && slope != null;
  bool get isOperational =>
      (phase == CalibrationPhase.calibrated ||
          phase == CalibrationPhase.unstable) &&
      hasReference;

  double? apply(double rawVoltage) {
    if (!isOperational || baseline == null || slope == null) return null;
    return slope! * (rawVoltage - baseline!) + (intercept ?? 0);
  }
}

class CalibrationService {
  final Map<String, _CalibrationState> _states = {};
  final Map<String, SetupProfile> _profiles = {};


  // Ultra-fast calibration parameters
  final int minSamples = 3; // Just need a few samples for averaging
  final double targetNoise = 0.020; // Very relaxed
  final double targetDrift = 0.020; // Very relaxed
  final Duration window = const Duration(seconds: 5);
  
  // Known pump characteristics
  double pumpMinVelocity = 24.0; // cm/s
  double pumpMaxVelocity = 40.0; // cm/s
  
  // ESP32 FIRMWARE BUG WORKAROUND
  // ESP32 uses wrong LSB factor (±0.256V instead of ±2.048V)
  // Multiply all incoming voltages by 8 to correct
  final double esp32VoltageCorrection = 8.0;

  CalibrationStatus statusForProfile(String? profileId) {
    if (profileId == null) {
      return CalibrationStatus(
        profileId: '',
        phase: CalibrationPhase.uncalibrated,
        sampleCount: 0,
        noise: 0,
        drift: 0,
        stabilityScore: 0,
        referenceIsElectrical: false,
        message: "Select setup profile first",
      );
    }
    return _states[profileId]?.status ??
        _CalibrationState(
          profileId: profileId,
          targetDrift: targetDrift,
          targetNoise: targetNoise,
          window: window,
          minSamples: minSamples,
          pumpMinVelocity: pumpMinVelocity,
          pumpMaxVelocity: pumpMaxVelocity,
        ).status;
  }

  void addSample(String? profileId, double rawVoltage,
      {bool requireReference = true}) {
    if (profileId == null) return;
    
    // Apply ESP32 firmware correction
    final correctedVoltage = rawVoltage * esp32VoltageCorrection;
    
    final state = _states.putIfAbsent(
      profileId,
      () => _CalibrationState(
        profileId: profileId,
        targetNoise: targetNoise,
        targetDrift: targetDrift,
        window: window,
        minSamples: minSamples,
        pumpMinVelocity: pumpMinVelocity,
        pumpMaxVelocity: pumpMaxVelocity,
      ),
    );
    state.addSample(correctedVoltage, requireReference: requireReference);
  }

  void updateVelocityRange(double minVelocity, double maxVelocity) {
    pumpMinVelocity = minVelocity;
    pumpMaxVelocity = maxVelocity;
    for (final state in _states.values) {
      state.updatePumpRange(minVelocity, maxVelocity);
    }
  }

  void registerProfile(SetupProfile profile) {
    _profiles[profile.id] = profile;
  }

  bool captureReference(String? profileId, double knownVelocity,
      {bool electricalReference = false}) {
    if (profileId == null) return false;
    final state = _states.putIfAbsent(
      profileId,
      () => _CalibrationState(
        profileId: profileId,
        targetNoise: targetNoise,
        targetDrift: targetDrift,
        window: window,
        minSamples: minSamples,
        pumpMinVelocity: pumpMinVelocity,
        pumpMaxVelocity: pumpMaxVelocity,
      ),
    );
    return state.captureReference(knownVelocity,
        electricalReference: electricalReference);
  }

  double? apply(String? profileId, double rawVoltage) {
    if (profileId == null) return null;
    
    // Apply ESP32 firmware correction
    final correctedVoltage = rawVoltage * esp32VoltageCorrection;
    
    final state = _states[profileId];
    final calibratedVelocity = state?.apply(correctedVoltage);
    
    if (calibratedVelocity == null) return null;
    
    // Apply profile-specific corrections AFTER calibration
    final profile = _profiles[profileId];
    if (profile == null) return calibratedVelocity;
    
    return _applyProfileCorrections(calibratedVelocity, profile);
  }
  
  // Profile-aware corrections applied to final velocity
  double _applyProfileCorrections(double velocity, SetupProfile profile) {
    var corrected = velocity;
    
    // 1. Electrode type correction
    // Wire electrodes typically have ~15% higher sensitivity than sheet
    if (profile.electrodeType == ElectrodeType.pin) {
      corrected *= 0.87; // Reduce by 15% to compensate
    }
    
    // 2. Coupling mode correction
    // Capacitive coupling attenuates DC component and low frequencies
    if (profile.couplingMode == CouplingMode.capacitive) {
      // AC coupling typically reduces apparent velocity by 5-10% for steady flow
      corrected *= 1.08; // Boost to compensate for attenuation
    }
    
    // 3. Magnet configuration correction
    // More magnets = stronger field = higher voltage for same velocity
    // Normalize to 16 magnets as baseline
    final magnetFactor = profile.magnetCount / 16.0;
    corrected /= magnetFactor;
    
    // 4. Magnet size correction
    // Larger magnets = stronger field
    // Normalize to 10mm as baseline
    final sizeFactor = profile.magnetSizeMm / 10.0;
    corrected /= sizeFactor;
    
    return corrected;
  }

  void resetProfile(String? profileId) {
    if (profileId == null) return;
    _states[profileId] = _CalibrationState(
      profileId: profileId,
      targetNoise: targetNoise,
      targetDrift: targetDrift,
      window: window,
      minSamples: minSamples,
      pumpMinVelocity: pumpMinVelocity,
      pumpMaxVelocity: pumpMaxVelocity,
    );
  }
}

class _CalibrationState {
  _CalibrationState({
    required this.profileId,
    required this.targetNoise,
    required this.targetDrift,
    required this.window,
    required this.minSamples,
    required this.pumpMinVelocity,
    required this.pumpMaxVelocity,
  });

  final String profileId;
  final double targetNoise;
  final double targetDrift;
  final Duration window;
  final int minSamples;
  double pumpMinVelocity;
  double pumpMaxVelocity;

  final List<_Sample> _samples = [];

  CalibrationPhase _phase = CalibrationPhase.uncalibrated;
  double? _baseline;
  double? _slope;
  double? _intercept = 0;
  double? _referenceVelocity;
  double? _referenceVoltage;
  String? _message = "Calibration required for current setup profile.";
  bool _referenceIsElectrical = false;

  CalibrationStatus get status => CalibrationStatus(
        profileId: profileId,
        phase: _phase,
        sampleCount: _samples.length,
        baseline: _baseline,
        noise: _noise,
        drift: _drift,
        slope: _slope,
        intercept: _intercept,
        stabilityScore: _stabilityScore,
        referenceVelocity: _referenceVelocity,
        referenceVoltage: _referenceVoltage,
        referenceIsElectrical: _referenceIsElectrical,
        message: _message,
      );

  double get _noise {
    if (_samples.isEmpty) return 0;
    final mean = _mean;
    final sumSq =
        _samples.fold<double>(0, (sum, s) => sum + pow(s.value - mean, 2));
    return sqrt(sumSq / _samples.length);
  }

  double get _drift {
    if (_samples.length < 2) return 0;
    return (_samples.last.value - _samples.first.value).abs();
  }

  double get _mean {
    if (_samples.isEmpty) return 0;
    final total = _samples.fold<double>(0, (sum, s) => sum + s.value);
    return total / _samples.length;
  }

  double get _stabilityScore {
    if (_samples.length < minSamples) {
      return (_samples.length / minSamples);
    }
    return 1.0;
  }

  void addSample(double rawVoltage, {bool requireReference = true}) {
    final now = DateTime.now();
    _samples.add(_Sample(rawVoltage, now));

    if (_phase == CalibrationPhase.calibrated ||
        _phase == CalibrationPhase.unstable) {
      // Only apply window trimming after calibration is complete
      while (_samples.isNotEmpty &&
          now.difference(_samples.first.time) > window) {
        _samples.removeAt(0);
      }
      _monitorPostCalibration();
      return;
    }

    _phase = CalibrationPhase.profiling;
    if (_samples.length < minSamples) {
      _message = "Collecting baseline (${_samples.length}/$minSamples samples)…";
      return;
    }

    // Lock baseline immediately once we have minimum samples
    _baseline = _mean;
    if (requireReference) {
      _phase = CalibrationPhase.waitingForReference;
      _message =
          "Ready for reference. Turn on pump (${pumpMinVelocity.toStringAsFixed(0)}-${pumpMaxVelocity.toStringAsFixed(0)} cm/s).";
    } else {
      _slope = 1;
      _intercept = 0;
      _referenceVelocity = 0;
      _referenceVoltage = _baseline;
      _referenceIsElectrical = false;
      _phase = CalibrationPhase.calibrated;
      _message = "Baseline set at ${_baseline!.toStringAsFixed(4)} V.";
    }
  }

  bool captureReference(double knownVelocity,
      {bool electricalReference = false}) {
    if (_baseline == null) {
      _message = "Baseline not locked yet.";
      return false;
    }
    
    final referenceVoltage = _recentMean();
    final delta = referenceVoltage - _baseline!;
    
    // Validate the reference is reasonable given pump constraints
    if (delta.abs() < 0.005) {
      _message = "No flow detected. Turn on pump.";
      return false;
    }

    // Check if velocity is within pump's expected range
    if (knownVelocity < pumpMinVelocity - 2 ||
        knownVelocity > pumpMaxVelocity + 2) {
      _message =
          "Velocity ${knownVelocity.toStringAsFixed(1)} cm/s outside pump range (${pumpMinVelocity.toInt()}-${pumpMaxVelocity.toInt()} cm/s).";
      return false;
    }

    _slope = knownVelocity / delta;
    _intercept = 0;
    _referenceVelocity = knownVelocity;
    _referenceVoltage = referenceVoltage;
    _referenceIsElectrical = electricalReference;
    _phase = CalibrationPhase.calibrated;
    _message =
        "Calibrated: ${knownVelocity.toStringAsFixed(1)} cm/s at ${referenceVoltage.toStringAsFixed(4)} V (slope ${_slope!.toStringAsFixed(1)}).";
    return true;
  }

  void _monitorPostCalibration() {
    if (_baseline == null) return;
    final current = _recentMean();
    final driftFromBaseline = (current - _baseline!).abs();
    
    // Very lenient monitoring - only flag if drift is extreme
    if (driftFromBaseline > 0.100 || _noise > 0.050) {
      _phase = CalibrationPhase.unstable;
      _message =
          "Signal unstable (drift ${(driftFromBaseline * 1000).toStringAsFixed(1)} mV). Consider recalibrating.";
    }
  }

  double _recentMean({int count = 5}) {
    if (_samples.isEmpty) return 0;
    final start = _samples.length > count ? _samples.length - count : 0;
    final slice = _samples.sublist(start);
    final sum = slice.fold<double>(0, (s, v) => s + v.value);
    return sum / slice.length;
  }

  double? apply(double rawVoltage) => status.apply(rawVoltage);

  void updatePumpRange(double minVelocity, double maxVelocity) {
    pumpMinVelocity = minVelocity;
    pumpMaxVelocity = maxVelocity;
  }
}

class _Sample {
  final double value;
  final DateTime time;

  _Sample(this.value, this.time);
}
