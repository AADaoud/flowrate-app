import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const primary = Color(0xFF8A0304);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF2A0406),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 30,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        color: Colors.white,
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    useMaterial3: true,
  );
}
