import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, rootBundle;
import 'package:http/http.dart' as http;
import 'package:rive/rive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await RiveFile.initialize();
  runApp(const MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Artboard? _artboard;
  SMIBool? _isFlowing;

  double _velocity = 0;
  String? _deviceIp;
  Timer? _pollTimer;
  Timer? _loopTimer;

  bool _showDebug = false;
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _loadRive();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptForIp());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _loopTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRive() async {
    final data = await rootBundle.load('assets/bloodflow.riv');
    final file = RiveFile.import(data);
    final board = file.mainArtboard;

    final ctrl = StateMachineController.fromArtboard(board, 'State Machine 1');
    if (ctrl != null) {
      board.addController(ctrl);
      _isFlowing = ctrl.findInput<bool>('isFlowing') as SMIBool?;
      _isFlowing?.value = false;
    }
    setState(() => _artboard = board);
  }

  Future<void> _startPolling() async {
    _pollTimer?.cancel();
    if (_deviceIp == null || _deviceIp!.isEmpty) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final uri = Uri.parse('http://$_deviceIp/v');
        final res = await http.get(uri).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final map = jsonDecode(res.body) as Map<String, dynamic>;
          final double newVel = (map['velocity'] as num).toDouble();
          if (!mounted) return;
          setState(() {
            _velocity = newVel;
            _lastError = '';
          });
          _updateFlowState();
        } else {
          setState(() => _lastError = 'Invalid response: ${res.statusCode}');
        }
      } catch (e) {
        setState(() => _lastError = 'Polling error: $e');
        debugPrint('Polling error: $e');
      }
    });
  }

  void _updateFlowState() {
    _loopTimer?.cancel();
    if (_isFlowing == null) return;

    if (_velocity > 10) {
      if (!_isFlowing!.value) _isFlowing!.value = true;
      _loopTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _isFlowing!
          ..value = false
          ..value = true;
      });
    } else {
      _isFlowing!.value = false;
    }
  }

  Future<void> _promptForIp() async {
    final ctrl = TextEditingController(text: _deviceIp ?? '');
    final ip = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter device IP'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '192.168.0.123'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (ip != null && ip.isNotEmpty) {
      setState(() => _deviceIp = ip);
      _startPolling();
    }
  }

  void _resetState() {
    _pollTimer?.cancel();
    _loopTimer?.cancel();
    setState(() {
      _velocity = 0;
      _isFlowing?.value = false;
      _lastError = '';
    });
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A0406),
      body: SafeArea(
        child: Center(
          child: _artboard == null
              ? const CircularProgressIndicator()
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Rive(artboard: _artboard!, fit: BoxFit.cover),
                    ),
                    const Positioned(top: 16, child: Text('Blood Velocity', style: _header)),
                    Positioned(
                      top: 70,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_velocity.toStringAsFixed(1), style: _value),
                          const SizedBox(width: 6),
                          const Text('cm/s', style: _units),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -45, // moved down by 65px from original 20
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 72,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: IconButton(
                                icon: const Icon(Icons.settings, color: Colors.white, size: 32),
                                onPressed: _promptForIp,
                                tooltip: 'Settings',
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: IconButton(
                                icon: const Icon(Icons.home, color: Colors.white, size: 32),
                                onPressed: () {
                                  setState(() => _showDebug = !_showDebug);
                                },
                                tooltip: 'Debug Info',
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
                                onPressed: _resetState,
                                tooltip: 'Reset',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showDebug)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showDebug = false),
                          child: Container(
                            color: Colors.black.withOpacity(0.75),
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.all(32),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white38),
                                ),
                                child: DefaultTextStyle(
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('🔧 Debug Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Text('Device IP: ${_deviceIp ?? "Not set"}'),
                                      Text('Velocity: ${_velocity.toStringAsFixed(1)} cm/s'),
                                      Text('Error: ${_lastError.isEmpty ? "None" : _lastError}'),
                                      const SizedBox(height: 12),
                                      const Text('(Tap anywhere to close)', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ),
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

  static const _header = TextStyle(
    fontFamily: 'Inter',
    fontSize: 38,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static const _value = TextStyle(
    fontFamily: 'Inter',
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    shadows: [Shadow(blurRadius: 4, offset: Offset(2, 2))],
  );
  static const _units = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    color: Colors.white70,
  );
}
