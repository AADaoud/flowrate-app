import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rive/rive.dart';

import '../models/app_ble_status.dart';
import '../models/flow_reading.dart';
import '../models/velocity_sample.dart';
import '../services/ble_service.dart';
import '../services/calibration_service.dart';
import '../services/flow_controller.dart';
import '../widgets/battery_chip.dart';
import '../widgets/ble_status_bar.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/velocity_card.dart';
import 'calibration_screen.dart';
import 'device_info_screen.dart';
import 'history_screen.dart';
import 'setup_profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FlowController _controller;
  Artboard? _artboard;
  SMIBool? _isFlowing;
  StateMachineController? _riveController;

  bool _showDebugOverlay = false;
  FlowReading? _lastReadingFeedback;
  AppBleStage _lastStage = AppBleStage.idle;

  @override
  void initState() {
    super.initState();
    _controller = FlowController(BleVelocityService())
      ..addListener(_handleControllerUpdate);
    _loadRive();
    _initPermissionsAndBle();
  }

  Future<void> _initPermissionsAndBle() async {
    final granted = await _ensurePermissions();
    if (granted) {
      _controller.startBle();
    }
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final granted = statuses.values.every((s) => s.isGranted);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions are required to continue.'),
          ),
        );
      }
    }
    return granted;
  }

  Future<void> _loadRive() async {
    final data = await rootBundle.load('assets/bloodflow.riv');
    final file = RiveFile.import(data);
    final art = file.mainArtboard;
    final controller = StateMachineController.fromArtboard(art, 'State Machine 1');
    if (controller != null) {
      art.addController(controller);
      _riveController = controller;
      _isFlowing = controller.findInput<bool>('isFlowing') as SMIBool?;
      _isFlowing?.value = false;
    }
    setState(() {
      _artboard = art;
    });
  }

  void _handleControllerUpdate() {
    final status = _controller.status;
    final reading = _controller.latest;

    if (reading != null) {
      _updateFlowState(_controller.calibratedVelocity ?? 0);
      if (_controller.hapticsEnabled &&
          (_lastReadingFeedback?.timestamp != reading.timestamp)) {
        HapticFeedback.selectionClick();
      }
      if (_controller.soundEnabled &&
          (_lastReadingFeedback?.timestamp != reading.timestamp)) {
        SystemSound.play(SystemSoundType.click);
      }
      _lastReadingFeedback = reading;
    }

    if (status.stage != _lastStage) {
      if (_controller.hapticsEnabled) {
        if (status.stage == AppBleStage.connected) {
          HapticFeedback.mediumImpact();
        } else if (status.stage == AppBleStage.disconnected) {
          HapticFeedback.selectionClick();
        } else if (status.stage == AppBleStage.error) {
          HapticFeedback.vibrate();
        }
      }
      if (_controller.soundEnabled && status.stage == AppBleStage.connected) {
        SystemSound.play(SystemSoundType.alert);
      }
      _lastStage = status.stage;
    }

    if (mounted) setState(() {});
  }

  void _updateFlowState(double velocity) {
    if (_isFlowing == null || _riveController == null) return;
    
    // Set isFlowing to true when velocity > 5, false otherwise
    final shouldFlow = velocity > 5;
    
    if (_isFlowing!.value != shouldFlow) {
      _isFlowing!.value = shouldFlow;
      
      // Reset animation when stopping flow
      if (!shouldFlow) {
        // Force state machine to reset by re-initializing
        _riveController!.isActive = false;
        _riveController!.isActive = true;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          samples: List<VelocitySample>.from(_controller.history),
        ),
      ),
    );
  }

  void _openCalibration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalibrationScreen(
          controller: _controller,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          loggingEnabled: _controller.loggingEnabled,
          devMode: _controller.devMode,
          hapticsEnabled: _controller.hapticsEnabled,
          soundEnabled: _controller.soundEnabled,
          onLoggingChanged: (v) => _controller.toggleLogging(v),
          onDevModeChanged: (v) => _controller.setDevMode(v),
          onHapticsChanged: (v) => _controller.setHaptics(v),
          onSoundChanged: (v) => _controller.setSound(v),
        ),
      ),
    );
  }

  void _openDeviceInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceInfoScreen(
          ble: _controller.ble,
          battery: _controller.latest?.battery,
        ),
      ),
    );
  }

  void _toggleDebug() {
    setState(() {
      _showDebugOverlay = !_showDebugOverlay;
      _controller.setDevMode(true);
    });
  }

  void _openSetupProfiles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetupProfileScreen(controller: _controller),
      ),
    );
  }

  List<double> _sparkline() {
    if (_controller.history.isEmpty) return [];
    final history = _controller.history;
    final startIndex = history.length > 60 ? history.length - 60 : 0;
    return history
        .sublist(startIndex)
        .map((e) => e.value)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    final reading = _controller.latest;
    final calibration = _controller.calibrationStatus;
    final velocity = _controller.calibratedVelocity;
    final isCalibrated = _controller.calibrationMatchesProfile;
    final rawVoltage = reading?.rawVoltage ?? 0;
    final battery = reading?.battery ?? _controller.lastBattery;
    final status = _controller.status;
    final profileLabel = _controller.activeProfile?.label ?? 'None';
    final statusText = !_controller.hasProfile
        ? 'Select setup profile first'
        : (!isCalibrated
            ? 'Calibration required for current setup profile'
            : (calibration.message ??
                'Calibrated profile active for this setup'));

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: m.LinearGradient(
              colors: [Color(0xFF12142A), Color(0xFF0E101C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top status bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          BatteryChip(battery: battery),
                          const SizedBox(width: 10),
                          BleStatusBar(status: status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Rive Animation Card
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 160),
                          child: artboard == null
                              ? const Center(child: CircularProgressIndicator())
                              : Rive(
                                  artboard: artboard,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Velocity Card
                      VelocityCard(
                        rawVoltage: rawVoltage,
                        velocity: velocity,
                        samples: _sparkline(),
                        isCalibrated: _controller.calibrationMatchesProfile,
                        statusText: statusText,
                        baseline: calibration.baseline,
                        noise: calibration.noise,
                        drift: calibration.drift,
                      ),
                      const SizedBox(height: 16),
                      
                      // Info tiles
                      Row(
                        children: [
                          _InfoTile(
                            label: 'RSSI',
                            value: '${_controller.ble.lastRssi ?? 0} dBm',
                            icon: Icons.network_ping,
                          ),
                          const SizedBox(width: 12),
                          _InfoTile(
                            label: 'Last packet',
                            value: _controller.lastReadingReceived == null
                                ? '—'
                                : _timeAgo(_controller.lastReadingReceived!),
                            icon: Icons.schedule,
                          ),
                          const SizedBox(width: 12),
                          _InfoTile(
                            label: 'Battery',
                            value: '${battery ?? 0}%',
                            icon: Icons.bolt,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Action chips
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _chipAction(
                            icon: Icons.settings_input_component,
                            label: 'Setup profile',
                            onTap: _openSetupProfiles,
                          ),
                          _chipAction(
                            icon: Icons.refresh,
                            label: 'Rescan',
                            onTap: () => _controller.ble.reset(),
                          ),
                          _chipAction(
                            icon: Icons.timeline,
                            label: 'History',
                            onTap: _openHistory,
                          ),
                          _chipAction(
                            icon: Icons.tune,
                            label: 'Calibrate',
                            onTap: _openCalibration,
                          ),
                          _chipAction(
                            icon: Icons.settings,
                            label: 'Settings',
                            onTap: _openSettings,
                          ),
                          _chipAction(
                            icon: Icons.info_outline,
                            label: 'Device info',
                            onTap: _openDeviceInfo,
                          ),
                          if (_controller.devMode)
                            _chipAction(
                              icon: Icons.bug_report,
                              label: 'Debug overlay',
                              onTap: _toggleDebug,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Status message
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          status.message,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Debug overlay
              if (_controller.devMode && _showDebugOverlay)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showDebugOverlay = false);
                    },
                    child: DebugOverlay(
                      deviceName: _controller.ble.device?.name ?? 'Unknown',
                      deviceId: _controller.ble.device?.id ?? '-',
                      velocity: velocity,
                      rawVoltage: rawVoltage,
                      calibrated: isCalibrated,
                      profileLabel: profileLabel,
                      battery: battery,
                      rssi: _controller.ble.lastRssi,
                      lastStatus: status.toString(),
                      error: status.isError ? status.message : '',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}