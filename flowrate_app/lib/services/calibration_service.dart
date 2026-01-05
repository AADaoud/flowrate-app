import 'dart:math';

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

  // Tunable heuristics
  final int minSamples = 15;
  final double targetNoise = 0.005; // 5 mV
  final double targetDrift = 0.0045; // 4.5 mV over the window
  final Duration window = const Duration(seconds: 28);

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
        ).status;
  }

  void addSample(String? profileId, double rawVoltage,
      {bool requireReference = true}) {
    if (profileId == null) return;
    final state = _states.putIfAbsent(
      profileId,
      () => _CalibrationState(
        profileId: profileId,
        targetNoise: targetNoise,
        targetDrift: targetDrift,
        window: window,
        minSamples: minSamples,
      ),
    );
    state.addSample(rawVoltage, requireReference: requireReference);
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
      ),
    );
    return state.captureReference(knownVelocity,
        electricalReference: electricalReference);
  }

  double? apply(String? profileId, double rawVoltage) {
    if (profileId == null) return null;
    final state = _states[profileId];
    return state?.apply(rawVoltage);
  }

  void resetProfile(String? profileId) {
    if (profileId == null) return;
    _states[profileId] = _CalibrationState(
      profileId: profileId,
      targetNoise: targetNoise,
      targetDrift: targetDrift,
      window: window,
      minSamples: minSamples,
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
  });

  final String profileId;
  final double targetNoise;
  final double targetDrift;
  final Duration window;
  final int minSamples;

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
    final countScore = (_samples.length / minSamples).clamp(0, 1);
    final noiseScore = 1 - (_noise / targetNoise).clamp(0, 1);
    final driftScore = 1 - (_drift / targetDrift).clamp(0, 1);
    return (countScore * 0.4) + (noiseScore * 0.35) + (driftScore * 0.25);
  }

  void addSample(double rawVoltage, {bool requireReference = true}) {
    final now = DateTime.now();
    _samples.add(_Sample(rawVoltage, now));

    while (_samples.isNotEmpty &&
        now.difference(_samples.first.time) > window) {
      _samples.removeAt(0);
    }

    if (_phase == CalibrationPhase.calibrated ||
        _phase == CalibrationPhase.unstable) {
      _monitorPostCalibration();
      return;
    }

    _phase = CalibrationPhase.profiling;
    if (_samples.length < minSamples) {
      _message = "Collecting baseline samples for this setup profile…";
      return;
    }

    final stableNoise = _noise <= targetNoise;
    final stableDrift = _drift <= targetDrift;
    if (stableNoise && stableDrift ||
        _stabilityScore > 0.82) {
      _baseline = _mean;
      if (requireReference) {
        _phase = CalibrationPhase.waitingForReference;
        _message =
            "Baseline locked at ${_baseline!.toStringAsFixed(4)} V. Attach reference or hold known flow.";
      } else {
        _slope = 1;
        _intercept = 0;
        _referenceVelocity = 0;
        _referenceVoltage = _baseline;
        _referenceIsElectrical = false;
        _phase = CalibrationPhase.calibrated;
        _message =
            "Baseline locked at ${_baseline!.toStringAsFixed(4)} V. Reference capture skipped.";
      }
    } else {
      _message =
          "Waiting for stability (noise ${_noise.toStringAsFixed(4)} V, drift ${_drift.toStringAsFixed(4)} V)";
    }
  }

  bool captureReference(double knownVelocity,
      {bool electricalReference = false}) {
    if (_baseline == null) {
      _message = "Baseline not locked yet for this setup profile.";
      return false;
    }
    final referenceVoltage = _recentMean();
    final delta = referenceVoltage - _baseline!;
    if (delta.abs() < 1e-5) {
      _message = "Reference change too small to calibrate.";
      return false;
    }

    _slope = knownVelocity / delta;
    _intercept = 0;
    _referenceVelocity = knownVelocity;
    _referenceVoltage = referenceVoltage;
    _referenceIsElectrical = electricalReference;
    _phase = CalibrationPhase.calibrated;
    _message =
        "Calibrated with ${knownVelocity.toStringAsFixed(1)} cm/s reference.";
    return true;
  }

  void _monitorPostCalibration() {
    if (_baseline == null) return;
    final current = _recentMean();
    final driftFromBaseline = (current - _baseline!).abs();
    if (driftFromBaseline > targetDrift * 4 || _noise > targetNoise * 4) {
      _phase = CalibrationPhase.unstable;
      _message =
          "Reduced confidence for current setup (drift ${driftFromBaseline.toStringAsFixed(4)} V).";
    }
  }

  double _recentMean({int count = 8}) {
    if (_samples.isEmpty) return 0;
    final start = _samples.length > count ? _samples.length - count : 0;
    final slice = _samples.sublist(start);
    final sum = slice.fold<double>(0, (s, v) => s + v.value);
    return sum / slice.length;
  }

  double? apply(double rawVoltage) => status.apply(rawVoltage);
}

class _Sample {
  final double value;
  final DateTime time;

  _Sample(this.value, this.time);
}
