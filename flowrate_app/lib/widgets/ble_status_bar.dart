import 'package:flutter/material.dart';

import '../models/app_ble_status.dart';

class BleStatusBar extends StatelessWidget {
  final AppBleStatus status;
  final bool showPulse;

  const BleStatusBar({super.key, required this.status, this.showPulse = true});

  Color _bgColor() {
    switch (status.stage) {
      case AppBleStage.connected:
        return Colors.greenAccent.withOpacity(0.25);
      case AppBleStage.scanning:
      case AppBleStage.connecting:
        return Colors.orangeAccent.withOpacity(0.25);
      case AppBleStage.error:
        return Colors.redAccent.withOpacity(0.28);
      case AppBleStage.disconnected:
      case AppBleStage.idle:
      default:
        return Colors.white10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth,
            size: 18,
            color: status.stage == AppBleStage.connected
                ? Colors.white
                : Colors.white70,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              status.message,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showPulse) ...[
            const SizedBox(width: 10),
            _Pulse(status: status.stage),
          ]
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final AppBleStage status;

  const _Pulse({required this.status});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = switch (widget.status) {
      AppBleStage.connected => Colors.greenAccent,
      AppBleStage.error => Colors.redAccent,
      AppBleStage.scanning || AppBleStage.connecting => Colors.amberAccent,
      _ => Colors.white38,
    };

    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(Icons.fiber_manual_record, size: 10, color: activeColor),
    );
  }
}
