import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  final bool loggingEnabled;
  final bool devMode;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final double voltageMin;
  final double voltageMax;
  final double velocityMin;
  final double velocityMax;
  final bool invertPolarity;

  final ValueChanged<bool> onLoggingChanged;
  final ValueChanged<bool> onDevModeChanged;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<(double, double)> onVoltageRangeChanged;
  final ValueChanged<(double, double)> onVelocityRangeChanged;
  final ValueChanged<bool> onPolarityChanged;

  const SettingsScreen({
    super.key,
    required this.loggingEnabled,
    required this.devMode,
    required this.hapticsEnabled,
    required this.soundEnabled,
    required this.voltageMin,
    required this.voltageMax,
    required this.velocityMin,
    required this.velocityMax,
    required this.invertPolarity,
    required this.onLoggingChanged,
    required this.onDevModeChanged,
    required this.onHapticsChanged,
    required this.onSoundChanged,
    required this.onVoltageRangeChanged,
    required this.onVelocityRangeChanged,
    required this.onPolarityChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _loggingEnabled;
  late bool _devMode;
  late bool _hapticsEnabled;
  late bool _soundEnabled;
  late double _voltageMin;
  late double _voltageMax;
  late double _velocityMin;
  late double _velocityMax;
  late bool _invertPolarity;
  late final TextEditingController _voltageMinController;
  late final TextEditingController _voltageMaxController;
  late final TextEditingController _velocityMinController;
  late final TextEditingController _velocityMaxController;

  @override
  void initState() {
    super.initState();
    _loggingEnabled = widget.loggingEnabled;
    _devMode = widget.devMode;
    _hapticsEnabled = widget.hapticsEnabled;
    _soundEnabled = widget.soundEnabled;
    _voltageMin = widget.voltageMin;
    _voltageMax = widget.voltageMax;
    _velocityMin = widget.velocityMin;
    _velocityMax = widget.velocityMax;
    _invertPolarity = widget.invertPolarity;
    _voltageMinController =
        TextEditingController(text: _voltageMin.toStringAsFixed(2));
    _voltageMaxController =
        TextEditingController(text: _voltageMax.toStringAsFixed(2));
    _velocityMinController =
        TextEditingController(text: _velocityMin.toStringAsFixed(1));
    _velocityMaxController =
        TextEditingController(text: _velocityMax.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _voltageMinController.dispose();
    _voltageMaxController.dispose();
    _velocityMinController.dispose();
    _velocityMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // ===========================
              // Custom App Bar
              // ===========================
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
                          'Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Customize your experience',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ===========================
              // Settings List
              // ===========================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SettingCard(
                        title: 'Enable Logging / History',
                        description:
                            'Store recent velocity samples for the history graph',
                        value: _loggingEnabled,
                        icon: Icons.storage_rounded,
                        onChanged: (v) {
                          setState(() => _loggingEnabled = v);
                          widget.onLoggingChanged(v);
                        },
                      ),
                      const SizedBox(height: 16),

                      _SettingCard(
                        title: 'Developer Mode',
                        description:
                            'Enable debug overlay and extra diagnostics',
                        value: _devMode,
                        icon: Icons.developer_mode,
                        onChanged: (v) {
                          setState(() => _devMode = v);
                          widget.onDevModeChanged(v);
                        },
                      ),
                      const SizedBox(height: 16),

                      _SettingCard(
                        title: 'Haptics',
                        description:
                            'Vibrate when connection or data updates occur',
                        value: _hapticsEnabled,
                        icon: Icons.vibration,
                        onChanged: (v) {
                          setState(() => _hapticsEnabled = v);
                          widget.onHapticsChanged(v);
                        },
                      ),
                      const SizedBox(height: 16),

                      _SettingCard(
                        title: 'Sound Effects',
                        description:
                            'Play subtle system sounds when events occur',
                        value: _soundEnabled,
                        icon: Icons.volume_up_rounded,
                        onChanged: (v) {
                          setState(() => _soundEnabled = v);
                          widget.onSoundChanged(v);
                        },
                      ),
                      const SizedBox(height: 24),

                      if (_devMode) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Developer Options',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RangeSettingCard(
                          title: 'Expected Voltage Range (V)',
                          description:
                              'Clamp incoming voltage measurements to stay within this range.',
                          minController: _voltageMinController,
                          maxController: _voltageMaxController,
                          minLabel: 'Min V',
                          maxLabel: 'Max V',
                          onMinChanged: (value) {
                            final parsed = _tryParse(value);
                            if (parsed != null) {
                              setState(() => _voltageMin = parsed);
                              _updateVoltageRange(min: parsed);
                            }
                          },
                          onMaxChanged: (value) {
                            final parsed = _tryParse(value);
                            if (parsed != null) {
                              setState(() => _voltageMax = parsed);
                              _updateVoltageRange(max: parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _RangeSettingCard(
                          title: 'Expected Velocity Range (cm/s)',
                          description:
                              'Clamp displayed velocity values to stay within this range.',
                          minController: _velocityMinController,
                          maxController: _velocityMaxController,
                          minLabel: 'Min',
                          maxLabel: 'Max',
                          onMinChanged: (value) {
                            final parsed = _tryParse(value);
                            if (parsed != null) {
                              setState(() => _velocityMin = parsed);
                              _updateVelocityRange(min: parsed);
                            }
                          },
                          onMaxChanged: (value) {
                            final parsed = _tryParse(value);
                            if (parsed != null) {
                              setState(() => _velocityMax = parsed);
                              _updateVelocityRange(max: parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _SettingCard(
                          title: 'Invert Voltage Polarity',
                          description:
                              'Flip incoming voltages when sensor leads are reversed.',
                          value: _invertPolarity,
                          icon: Icons.swap_vert_circle,
                          onChanged: (v) {
                            setState(() => _invertPolarity = v);
                            widget.onPolarityChanged(v);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ===========================
                      // Info Card
                      // ===========================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
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
                                    'About Settings',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'These options help fine-tune how the app interacts with your ESP32, providing control over diagnostics, feedback, and data recording.',
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
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _SettingsScreenParsing on _SettingsScreenState {
  double? _tryParse(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value);
  }

  void _updateVoltageRange({double? min, double? max}) {
    if (min != null) _voltageMin = min;
    if (max != null) _voltageMax = max;
    widget.onVoltageRangeChanged((_voltageMin, _voltageMax));
  }

  void _updateVelocityRange({double? min, double? max}) {
    if (min != null) _velocityMin = min;
    if (max != null) _velocityMax = max;
    widget.onVelocityRangeChanged((_velocityMin, _velocityMax));
  }
}

class _RangeSettingCard extends StatelessWidget {
  final String title;
  final String description;
  final TextEditingController minController;
  final TextEditingController maxController;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<String> onMinChanged;
  final ValueChanged<String> onMaxChanged;

  const _RangeSettingCard({
    required this.title,
    required this.description,
    required this.minController,
    required this.maxController,
    required this.minLabel,
    required this.maxLabel,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  @override
  Widget build(BuildContext context) {
    final inputFormatter = FilteringTextInputFormatter.allow(
      RegExp(r'^-?\d*\.?\d*$'),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RangeField(
                  label: minLabel,
                  controller: minController,
                  onChanged: onMinChanged,
                  inputFormatter: inputFormatter,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RangeField(
                  label: maxLabel,
                  controller: maxController,
                  onChanged: onMaxChanged,
                  inputFormatter: inputFormatter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputFormatter inputFormatter;

  const _RangeField({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.inputFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [inputFormatter],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _SettingCard({
    required this.title,
    required this.description,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Toggle
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}
