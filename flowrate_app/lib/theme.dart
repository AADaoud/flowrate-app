import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const seed = Color(0xFFd14f50);
  final base = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      surface: const Color(0xFF120607),
      surfaceContainerHighest: const Color(0xFF1f0a0c),
    ),
    scaffoldBackgroundColor: const Color(0xFF0f070a),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      displayMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      titleMedium: TextStyle(color: Colors.white70),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    cardColor: base.surfaceContainerHighest,
  );
}
