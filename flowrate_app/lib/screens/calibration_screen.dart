import 'package:flutter/material.dart';

import '../models/setup_profile.dart';
import '../services/calibration_service.dart';
import '../services/flow_controller.dart';
import 'setup_profile_screen.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.controller});

  final FlowController controller;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  double _referenceVelocity = 20;
  bool _electricalReference = false;
  late final TextEditingController _refController;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: '20');
    widget.controller.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _refController.dispose();
    widget.controller.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final calibration = widget.controller.calibrationStatus;
    final latest = widget.controller.latest;
    final rawVoltage = latest?.rawVoltage ?? 0;
    final hasProfile = widget.controller.activeProfile != null;
    final profile = widget.controller.activeProfile;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF12142A), Color(0xFF0E101C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calibration',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Baseline first, then reference',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _StatusPill(calibration: calibration),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _profileBanner(profile),
                        const SizedBox(height: 12),
                        _liveCard(calibration, rawVoltage, hasProfile),
                        const SizedBox(height: 16),
                        _baselineCard(calibration, hasProfile),
                        const SizedBox(height: 16),
                        _referenceCard(calibration, hasProfile),
                        const SizedBox(height: 16),
                        _confidenceCard(calibration),
                        const SizedBox(height: 16),
                        _whyCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileBanner(SetupProfile? profile) {
    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select or create a setup profile (magnets, pipe, electrodes, coupling) before calibration.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SetupProfileScreen(controller: widget.controller),
                  ),
                );
              },
              icon: const Icon(Icons.settings_input_component),
              label: const Text('Manage setup profiles'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active setup profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.magnetSizeMm.toStringAsFixed(0)} mm magnets × ${profile.magnetCount}\nPipe: ${profile.pipeDiameterMm.toStringAsFixed(0)} mm · Electrodes: ${profile.electrodeType.name}\nCoupling: ${profile.couplingMode.name}${profile.notes.isNotEmpty ? "\nNotes: ${profile.notes}" : ""}',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SetupProfileScreen(controller: widget.controller),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Switch profile'),
          ),
        ],
      ),
    );
  }

  Widget _liveCard(
      CalibrationStatus calibration, double rawVoltage, bool hasProfile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 8),
              const Text(
                'Live voltage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${rawVoltage.toStringAsFixed(4)} V',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasProfile
                ? (calibration.message ??
                    'Waiting for baseline stability before enabling velocity.')
                : 'Select a setup profile before profiling baseline.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: !hasProfile
                ? 0
                : calibration.phase == CalibrationPhase.calibrated
                    ? 1
                    : calibration.stabilityScore.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
              !hasProfile
                  ? Colors.orangeAccent
                  : calibration.phase == CalibrationPhase.calibrated
                      ? Colors.tealAccent
                      : Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stability score ${(calibration.stabilityScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _baselineCard(CalibrationStatus calibration, bool hasProfile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.lightBlueAccent),
              const SizedBox(width: 8),
              const Text(
                'Step 1 · Stabilize baseline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (calibration.baseline != null)
                Text(
                  'V₀ ${calibration.baseline!.toStringAsFixed(4)} V',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Keep the sensor in a no-flow / reference condition until the mean voltage stops drifting. Baseline must be earned because the floating input sits near 0.0359 V even with nothing attached.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metricChip('Noise', '${calibration.noise.toStringAsFixed(4)} V'),
              _metricChip('Drift', '${calibration.drift.toStringAsFixed(4)} V'),
              _metricChip('Samples', '${calibration.sampleCount} pts'),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: hasProfile
                ? () {
                    widget.controller.resetCalibration();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.08),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset baseline profiling'),
          ),
        ],
      ),
    );
  }

  Widget _referenceCard(CalibrationStatus calibration, bool hasProfile) {
    final waiting = calibration.phase == CalibrationPhase.waitingForReference ||
        calibration.phase == CalibrationPhase.unstable;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              const Text(
                'Step 2 · Attach known reference',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Apply a known electrical or flow reference, enter its velocity, and capture it. Velocity output stays locked until this step completes.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Known velocity (cm/s)',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.tealAccent.withOpacity(0.8)),
                    ),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) {
                      _referenceVelocity = parsed;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Switch(
                    value: _electricalReference,
                    onChanged: (v) {
                      setState(() => _electricalReference = v);
                    },
                    activeColor: Colors.tealAccent,
                  ),
                  Text(
                    'Electrical\nreference',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: hasProfile && waiting
                ? () {
                    final ok = widget.controller.captureReference(
                      _referenceVelocity,
                      electricalReference: _electricalReference,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Reference captured — velocity unlocked.'
                              : widget.controller.calibrationStatus.message ??
                                  'Unable to capture reference.',
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.withOpacity(0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('Capture reference now'),
          ),
          const SizedBox(height: 8),
          if (calibration.hasReference)
            Text(
              'Reference locked at ${calibration.referenceVelocity?.toStringAsFixed(1)} cm/s (${calibration.referenceVoltage?.toStringAsFixed(4)} V, ${calibration.referenceIsElectrical ? "electrical bias" : "flow reference"}).',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              hasProfile
                  ? 'Tip: toggle the switch if you are injecting a known electrical bias instead of fluid flow.'
                  : 'Select a setup profile before capturing a reference.',
              style: TextStyle(color: Colors.white.withOpacity(0.65)),
            ),
        ],
      ),
    );
  }

  Widget _confidenceCard(CalibrationStatus calibration) {
    final isOperational = calibration.isOperational;
    final reduced = calibration.phase == CalibrationPhase.unstable;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield,
                color:
                    isOperational ? Colors.tealAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Confidence ${((calibration.stabilityScore) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!isOperational)
                const Text(
                  'Velocity locked for this profile',
                  style: TextStyle(color: Colors.orangeAccent),
                )
              else if (reduced)
                const Text(
                  'Reduced confidence for current setup',
                  style: TextStyle(color: Colors.amberAccent),
                )
              else
                const Text(
                  'Velocity enabled',
                  style: TextStyle(color: Colors.tealAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Velocity output appears only after a profile-specific baseline stabilizes and a reference is captured. If drift or noise spikes, confidence drops and you may choose to recalibrate.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why this wait exists',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Floating inputs sit around ~0.0359 V even when nothing is attached. Electrode chemistry, leakage, and EMI mean zero volts is never guaranteed. The app measures and locks that baseline before any velocity math can happen.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.calibration});

  final CalibrationStatus calibration;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    if (calibration.profileId.isEmpty) {
      color = Colors.orangeAccent;
      text = 'Select profile';
    } else {
      switch (calibration.phase) {
        case CalibrationPhase.uncalibrated:
        case CalibrationPhase.profiling:
          color = Colors.orangeAccent;
          text = 'Profiling';
          break;
        case CalibrationPhase.waitingForReference:
          color = Colors.amberAccent;
          text = 'Attach reference';
          break;
        case CalibrationPhase.calibrated:
          color = Colors.tealAccent;
          text = 'Operational';
          break;
        case CalibrationPhase.unstable:
          color = Colors.redAccent;
          text = 'Unstable';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
