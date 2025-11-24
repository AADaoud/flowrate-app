import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/velocity_sample.dart';

class HistoryScreen extends StatelessWidget {
  final List<VelocitySample> samples;

  const HistoryScreen({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _buildPoints();

    return Scaffold(
      appBar: AppBar(title: const Text('Flow History')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: samples.isEmpty
            ? const Center(
                child: Text(
                  'No history yet.\nStay connected to build a trend.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last ${samples.length} samples',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: false,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(color: Colors.white24),
                            bottom: BorderSide(color: Colors.white24),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points,
                            isCurved: true,
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<FlSpot> _buildPoints() {
    if (samples.isEmpty) return [];
    final start = samples.first.timestamp.millisecondsSinceEpoch.toDouble();

    return samples.map((s) {
      final t = (s.timestamp.millisecondsSinceEpoch.toDouble() - start) / 1000.0;
      return FlSpot(t, s.value);
    }).toList();
  }
}
