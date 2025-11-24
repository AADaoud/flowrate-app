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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable logging / history'),
            subtitle:
                const Text('Store recent velocity samples for the history graph'),
            value: _loggingEnabled,
            onChanged: (v) {
              setState(() => _loggingEnabled = v);
              widget.onLoggingChanged(v);
            },
          ),
          SwitchListTile(
            title: const Text('Developer mode'),
            subtitle: const Text('Enable debug overlay and extra diagnostics'),
            value: _devMode,
            onChanged: (v) {
              setState(() => _devMode = v);
              widget.onDevModeChanged(v);
            },
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text('Vibrate when connection/data events occur'),
            value: _hapticsEnabled,
            onChanged: (v) {
              setState(() => _hapticsEnabled = v);
              widget.onHapticsChanged(v);
            },
          ),
          SwitchListTile(
            title: const Text('Sound effects'),
            subtitle: const Text('Play subtle system clicks when events happen'),
            value: _soundEnabled,
            onChanged: (v) {
              setState(() => _soundEnabled = v);
              widget.onSoundChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
