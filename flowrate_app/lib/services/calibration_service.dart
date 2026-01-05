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
  bool get isOperational => phase == CalibrationPhase.calibrated && hasReference;

  double? apply(double rawVoltage) {
    if (!isOperational || baseline == null || slope == null) return null;
    return slope! * (rawVoltage - baseline!) + (intercept ?? 0);
  }
}

class CalibrationService {
  final List<_Sample> _samples = [];

  CalibrationPhase _phase = CalibrationPhase.uncalibrated;
  double? _baseline;
  double? _slope;
  double? _intercept = 0;
  double? _referenceVelocity;
  double? _referenceVoltage;
  String? _message;
  bool _referenceIsElectrical = false;

  // Tunable heuristics
  final int minSamples = 25;
  final double targetNoise = 0.002; // 2 mV
  final double targetDrift = 0.0015; // 1.5 mV over the window
  final Duration window = const Duration(seconds: 35);

  CalibrationStatus get status => CalibrationStatus(
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
    final total =
        _samples.fold<double>(0, (sum, s) => sum + s.value);
    return total / _samples.length;
  }

  double get _stabilityScore {
    final countScore = (_samples.length / minSamples).clamp(0, 1);
    final noiseScore = 1 - (_noise / targetNoise).clamp(0, 1);
    final driftScore = 1 - (_drift / targetDrift).clamp(0, 1);
    return (countScore * 0.4) + (noiseScore * 0.35) + (driftScore * 0.25);
  }

  void addSample(double rawVoltage) {
    final now = DateTime.now();
    _samples.add(_Sample(rawVoltage, now));

    // trim window
    while (_samples.isNotEmpty &&
        now.difference(_samples.first.time) > window) {
      _samples.removeAt(0);
    }

    if (_phase == CalibrationPhase.calibrated) {
      _monitorPostCalibration();
      return;
    }

    if (_phase == CalibrationPhase.waitingForReference &&
        _samples.length >= minSamples * 2) {
      // Refresh baseline gently if drifted but keep phase.
      _baseline = _mean;
      return;
    }

    _phase = CalibrationPhase.profiling;
    if (_samples.length < minSamples) {
      _message = "Collecting baseline samples…";
      return;
    }

    final stableNoise = _noise <= targetNoise;
    final stableDrift = _drift <= targetDrift;
    if (stableNoise && stableDrift) {
      _baseline = _mean;
      _phase = CalibrationPhase.waitingForReference;
      _message =
          "Baseline locked at ${_baseline!.toStringAsFixed(4)} V. Attach reference or hold known flow.";
    } else {
      _message = "Waiting for stability (noise ${_noise.toStringAsFixed(4)} V, drift ${_drift.toStringAsFixed(4)} V)";
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

  void reset() {
    _samples.clear();
    _baseline = null;
    _slope = null;
    _intercept = 0;
    _referenceVelocity = null;
    _referenceVoltage = null;
    _referenceIsElectrical = false;
    _phase = CalibrationPhase.uncalibrated;
    _message = "Calibration reset. Waiting for baseline.";
  }

  void _monitorPostCalibration() {
    if (_baseline == null) return;
    final current = _recentMean();
    final driftFromBaseline = (current - _baseline!).abs();
    if (driftFromBaseline > targetDrift * 4 || _noise > targetNoise * 4) {
      _phase = CalibrationPhase.unstable;
      _message =
          "Baseline drifted (${driftFromBaseline.toStringAsFixed(4)} V). Recalibration required.";
    }
  }

  double _recentMean({int count = 8}) {
    if (_samples.isEmpty) return 0;
    final start = _samples.length > count ? _samples.length - count : 0;
    final slice = _samples.sublist(start);
    final sum = slice.fold<double>(0, (s, v) => s + v.value);
    return sum / slice.length;
  }
}

class _Sample {
  final double value;
  final DateTime time;

  _Sample(this.value, this.time);
}
