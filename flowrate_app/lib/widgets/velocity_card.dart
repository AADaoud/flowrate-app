import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class VelocityCard extends StatelessWidget {
  const VelocityCard({
    super.key,
    required this.velocity,
    required this.samples,
    this.maxVelocity = 120,
  });

  final double velocity;
  final double maxVelocity;
  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    final clamped = velocity.clamp(0, maxVelocity);
    final progress = (clamped / maxVelocity).clamp(0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1F35), Color(0xFF181926)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Velocity',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Live',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(
                            colorScheme.primary,
                            Colors.tealAccent,
                            value,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          velocity.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'cm/s',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent trend',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: samples.isEmpty
                    ? 10
                    : (samples.reduce((a, b) => a > b ? a : b) * 1.2),
                minX: 0,
                maxX: samples.isEmpty ? 1 : samples.length.toDouble(),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < samples.length; i++)
                        FlSpot(i.toDouble(), samples[i]),
                    ],
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withOpacity(0.18),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
