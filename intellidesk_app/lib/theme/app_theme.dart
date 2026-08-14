import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBrand = Color(0xFF0D9488); // Deep Clinical Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSlate = Color(0xFFF8FAFC);

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryBrand,
    scaffoldBackgroundColor: surfaceWhite,
    colorScheme: const ColorScheme.light(
      primary: primaryBrand,
      secondary: accentCyan,
      error: emergencyRed,
    ),
    brightness: Brightness.light,
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: primaryDark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: primaryDark,
      secondary: accentSky,
      error: emergencyRed,
    ),
    brightness: Brightness.dark,
  );
}
