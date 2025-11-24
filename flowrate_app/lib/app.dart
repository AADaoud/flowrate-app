import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

class FlowRateApp extends StatelessWidget {
  const FlowRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Velocity Sensor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
