import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool loggingEnabled;
  final bool devMode;
  final ValueChanged<bool> onLoggingChanged;
  final ValueChanged<bool> onDevModeChanged;

  const SettingsScreen({
    super.key,
    required this.loggingEnabled,
    required this.devMode,
    required this.onLoggingChanged,
    required this.onDevModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _loggingEnabled;
  late bool _devMode;

  @override
  void initState() {
    super.initState();
    _loggingEnabled = widget.loggingEnabled;
    _devMode = widget.devMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable logging / history'),
            subtitle: const Text(
                'Store recent velocity samples for the history graph'),
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
        ],
      ),
    );
  }
}
