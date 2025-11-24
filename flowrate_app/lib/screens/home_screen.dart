import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:rive/rive.dart';

import '../models/app_ble_status.dart';
import '../../models/velocity_sample.dart';
import '../services/ble_service.dart';
import '../../widgets/velocity_card.dart';
import '../../widgets/ble_status_bar.dart';
import '../../widgets/debug_overlay.dart';
import '../../widgets/battery_chip.dart';
import 'history_screen.dart';
import 'calibration_screen.dart';
import 'settings_screen.dart';
import 'device_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleVelocityService _ble = BleVelocityService();

  final List<VelocitySample> _history = [];
  double _velocity = 0;
  int? _battery;
  AppBleStatus _status =
      const AppBleStatus(AppBleStage.scanning, 'Starting…');

  bool _devMode = false;
  bool _loggingEnabled = true;
  bool _showDebugOverlay = false;
  String _lastError = '';

  Artboard? _artboard;
  SMIBool? _isFlowing;
  StreamSubscription<double>? _velSub;
  StreamSubscription<int?>? _batSub;
  StreamSubscription<AppBleStatus>? _statusSub;
  StreamSubscription<VelocitySample>? _historySub;

  @override
  void initState() {
    super.initState();
    _loadRive();
    _initPermissionsAndBle();
  }

  Future<void> _loadRive() async {
    final data = await rootBundle.load('assets/bloodflow.riv');
    final file = RiveFile.import(data);
    final art = file.mainArtboard;
    final controller =
        StateMachineController.fromArtboard(art, 'State Machine 1');
    if (controller != null) {
      art.addController(controller);
      _isFlowing = controller.findInput<bool>('isFlowing') as SMIBool?;
      _isFlowing?.value = false;
    }
    setState(() {
      _artboard = art;
    });
  }

  Future<void> _initPermissionsAndBle() async {
    await _ensurePermissions();
    _ble.start();

    // ---- Listen to velocity updates ----
    _velSub = _ble.velocityStream.listen((v) {
      setState(() {
        _velocity = v;
        _updateFlowState();

        if (_loggingEnabled) {
          _history.add(VelocitySample(v));
          if (_history.length > 300) {
            _history.removeAt(0);
          }
        }
      });
    });

    // ---- Listen to battery updates ----
    _batSub = _ble.batteryStream.listen((b) {
      setState(() {
        _battery = b;
      });
    });

    // ---- Listen to BLE status updates ----
    _statusSub = _ble.statusStream.listen((AppBleStatus s) {
      setState(() {
        _status = s;
        if (s.stage == AppBleStage.error) {
          _lastError = s.message;
        }
      });
    });
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  void _updateFlowState() {
    if (_isFlowing == null) return;
    _isFlowing!.value = _velocity > 10;
  }

  @override
  void dispose() {
    _velSub?.cancel();
    _batSub?.cancel();
    _statusSub?.cancel();
    _historySub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(samples: List.from(_history)),
      ),
    );
  }

  void _openCalibration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CalibrationScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          loggingEnabled: _loggingEnabled,
          devMode: _devMode,
          onLoggingChanged: (v) {
            setState(() => _loggingEnabled = v);
            if (!v) _history.clear();
          },
          onDevModeChanged: (v) {
            setState(() => _devMode = v);
          },
        ),
      ),
    );
  }

  void _openDeviceInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DeviceInfoScreen(ble: _ble, battery: _battery),
      ),
    );
  }

  void _toggleDebug() {
    setState(() {
      _showDebugOverlay = !_showDebugOverlay;
      _devMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // =======================
            // Background Rive Animation
            // =======================
            if (artboard == null)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Rive(
                    artboard: artboard,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // =======================
            // Velocity Card (ON TOP)
            // =======================
            Center(
              child: VelocityCard(
                velocity: _velocity,
                isFlowing: _velocity > 10,
              ),
            ),

            // =======================
            // Top-right buttons
            // =======================
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _openSettings,
                      ),
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.white),
                        onPressed: _openDeviceInfo,
                      ),
                      IconButton(
                        icon: const Icon(Icons.bug_report, color: Colors.white),
                        onPressed: _toggleDebug,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // =======================
            // Bottom Navigation
            // =======================
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navButton(
                    icon: Icons.info_outline,
                    label: 'Device',
                    onTap: _openDeviceInfo,
                  ),
                  _navButton(
                    icon: Icons.timeline,
                    label: 'History',
                    onTap: _openHistory,
                  ),
                  _navButton(
                    icon: Icons.tune,
                    label: 'Calibrate',
                    onTap: _openCalibration,
                  ),
                  _navButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: _openSettings,
                  ),
                  if (_devMode)
                    _navButton(
                      icon: Icons.bug_report,
                      label: 'Debug',
                      onTap: () {
                        setState(() => _showDebugOverlay = true);
                      },
                    ),
                ],
              ),
            ),

            // =======================
            // Debug Overlay
            // =======================
            if (_devMode && _showDebugOverlay)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showDebugOverlay = false);
                  },
                  child: DebugOverlay(
                    deviceName: _ble.device?.name ?? 'Unknown',
                    deviceId: _ble.device?.id ?? '-',
                    velocity: _velocity,
                    battery: _battery,
                    lastStatus: _status.toString(),
                    error: _lastError,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
