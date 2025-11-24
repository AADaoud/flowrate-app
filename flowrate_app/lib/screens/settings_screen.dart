import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool loggingEnabled;
  final bool devMode;
  final bool hapticsEnabled;
  final bool soundEnabled;

  final ValueChanged<bool> onLoggingChanged;
  final ValueChanged<bool> onDevModeChanged;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSoundChanged;

  const SettingsScreen({
    super.key,
    required this.loggingEnabled,
    required this.devMode,
    required this.hapticsEnabled,
    required this.soundEnabled,
    required this.onLoggingChanged,
    required this.onDevModeChanged,
    required this.onHapticsChanged,
    required this.onSoundChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _loggingEnabled;
  late bool _devMode;
  late bool _hapticsEnabled;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _loggingEnabled = widget.loggingEnabled;
    _devMode = widget.devMode;
    _hapticsEnabled = widget.hapticsEnabled;
    _soundEnabled = widget.soundEnabled;
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
