import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rive/rive.dart';

import '../models/app_ble_status.dart';
import '../models/telemetry_reading.dart';
import '../models/velocity_sample.dart';
import '../services/ble_service.dart';
import '../widgets/battery_chip.dart';
import '../widgets/ble_status_bar.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/velocity_card.dart';
import 'calibration_screen.dart';
import 'device_info_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

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
  DateTime? _lastReading;
  AppBleStatus _status = const AppBleStatus(AppBleStage.scanning, 'Starting…');

  bool _devMode = false;
  bool _loggingEnabled = true;
  bool _showDebugOverlay = false;
  bool _hapticsEnabled = true;
  bool _soundEnabled = false;
  String _lastError = '';

  Artboard? _artboard;
  SMIBool? _isFlowing;
  StreamSubscription<AppBleStatus>? _statusSub;
  StreamSubscription<TelemetryReading>? _telemetrySub;

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
    _listenToBle();
    _ble.start();
  }

  Future<void> _ensurePermissions() async {
    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final permanentlyDenied =
        statuses.values.any((s) => s.isPermanentlyDenied);
    if (permanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permissions needed'),
          content: const Text(
              'BLE and Location permissions are required to talk to the sensor.'
              ' Please enable them in Settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    }
  }

  void _listenToBle() {
    _telemetrySub = _ble.telemetryStream.listen((reading) {
      if (_hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        _velocity = reading.velocity;
        _battery = reading.battery;
        _lastReading = reading.timestamp;
        _updateFlowState();

        if (_loggingEnabled) {
          _history.add(VelocitySample(reading.velocity));
          if (_history.length > 360) _history.removeAt(0);
        }
      });
    });

    _statusSub = _ble.statusStream.listen((AppBleStatus s) {
      setState(() {
        _status = s;
        if (s.stage == AppBleStage.error) {
          _lastError = s.message;
        }
      });

      if (_hapticsEnabled &&
          (s.stage == AppBleStage.connected ||
              s.stage == AppBleStage.disconnected)) {
        HapticFeedback.mediumImpact();
      }
      if (_soundEnabled &&
          (s.stage == AppBleStage.connected || s.stage == AppBleStage.error)) {
        SystemSound.play(SystemSoundType.click);
      }
    });
  }

  void _updateFlowState() {
    if (_isFlowing == null) return;
    _isFlowing!.value = _velocity > 12;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(samples: _history.toList()),
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
          hapticsEnabled: _hapticsEnabled,
          soundEnabled: _soundEnabled,
          onLoggingChanged: (v) {
            setState(() => _loggingEnabled = v);
            if (!v) _history.clear();
          },
          onDevModeChanged: (v) {
            setState(() => _devMode = v);
          },
          onHapticsChanged: (v) {
            setState(() => _hapticsEnabled = v);
          },
          onSoundChanged: (v) {
            setState(() => _soundEnabled = v);
          },
        ),
      ),
    );
  }

  void _openDeviceInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceInfoScreen(ble: _ble, battery: _battery),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a0a0d), Color(0xFF12070a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (artboard != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.25,
                    child: Rive(
                      artboard: artboard,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        BleStatusBar(status: _status),
                        const Spacer(),
                        BatteryChip(battery: _battery),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            VelocityCard(
                              velocity: _velocity,
                              isFlowing: _velocity > 12,
                            ),
                            const SizedBox(height: 14),
                            _infoRow(),
                            const SizedBox(height: 12),
                            _navGrid(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              Positioned(
                top: 12,
                right: 12,
                child: Column(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow() {
    return Row(
      children: [
        Expanded(
          child: _pillCard(
            icon: Icons.history_toggle_off,
            title: 'Last sample',
            value: _lastReading == null
                ? 'Waiting for data'
                : _timeAgo(_lastReading!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pillCard(
            icon: Icons.rss_feed,
            title: 'RSSI',
            value: _ble.lastRssi != null ? '${_ble.lastRssi} dBm' : '—',
          ),
        ),
      ],
    );
  }

  Widget _navGrid() {
    final buttons = [
      _navButton(icon: Icons.info_outline, label: 'Device', onTap: _openDeviceInfo),
      _navButton(icon: Icons.timeline, label: 'History', onTap: _openHistory),
      _navButton(icon: Icons.tune, label: 'Calibrate', onTap: _openCalibration),
      _navButton(icon: Icons.settings, label: 'Settings', onTap: _openSettings),
      if (_devMode)
        _navButton(
          icon: Icons.bug_report,
          label: 'Debug',
          onTap: () => setState(() => _showDebugOverlay = true),
        ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
