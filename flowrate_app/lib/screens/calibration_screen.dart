import 'package:flutter/material.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder UI – ready to add calibration logic later
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Calibration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Coming soon:\n'
              '• Zero-point capture\n'
              '• Full-scale calibration\n'
              '• Fluid presets',
            ),
          ],
        ),
      ),
    );
  }
}
