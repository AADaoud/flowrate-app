import 'package:flutter/material.dart';

class VelocityCard extends StatelessWidget {
  final double velocity;
  final bool isFlowing;

  const VelocityCard({
    super.key,
    required this.velocity,
    required this.isFlowing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFlowing ? Colors.redAccent : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Velocity',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                velocity.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: color,
                  shadows: const [
                    Shadow(blurRadius: 4, offset: Offset(2, 2)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'cm/s',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
