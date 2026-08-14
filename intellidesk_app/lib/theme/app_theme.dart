import 'package:flutter/material.dart';

class AppTheme {
  // Primary Clinical Palette
  static const Color primaryBrand = Color(0xFF0D9488); // Deep Clinical Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryContainer = Color(0xFFCCFBF1); // Light Mint Tint
  static const Color accentCyan = Color(0xFF0284C7); // Medical Sky Blue
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color emergencyRed = Color(0xFFEF4444); // Urgent Coral Red
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSlate = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  // Emergency Severity Index (ESI) Triage Colors
  static const Color esi1Critical = Color(0xFFDC2626); // Deep Urgent Red
  static const Color esi2Emergent = Color(0xFFEA580C); // High Severity Orange
  static const Color esi3Urgent = Color(0xFFD97706); // Amber Warning Yellow
  static const Color routine = Color(0xFF16A34A); // Emerald Green Routine

  static Color getEsiColor(String? esiLevel) {
    if (esiLevel == null) return routine;
    final level = esiLevel.toUpperCase();
    if (level.contains('1') || level.contains('CRITICAL')) return esi1Critical;
    if (level.contains('2') || level.contains('EMERGENT')) return esi2Emergent;
    if (level.contains('3') || level.contains('URGENT')) return esi3Urgent;
    return routine;
  }

  static String getEsiLabel(String? esiLevel) {
    if (esiLevel == null) return 'Routine / Standard Care';
    final level = esiLevel.toUpperCase();
    if (level.contains('1') || level.contains('CRITICAL')) return 'ESI-1: Resuscitation / Critical (100% Relief)';
    if (level.contains('2') || level.contains('EMERGENT')) return 'ESI-2: Emergent / Acute Distress (80% Relief)';
    if (level.contains('3') || level.contains('URGENT')) return 'ESI-3: Urgent / Moderate Need (50% Relief)';
    return 'Routine: Standard Care (30% Relief)';
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryBrand,
    scaffoldBackgroundColor: surfaceSlate,
    colorScheme: const ColorScheme.light(
      primary: primaryBrand,
      primaryContainer: primaryContainer,
      secondary: accentCyan,
      error: emergencyRed,
      surface: surfaceWhite,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBrand,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderSubtle),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBrand,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    brightness: Brightness.light,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryDark,
    scaffoldBackgroundColor: const Color(0xFF090D16),
    colorScheme: const ColorScheme.dark(
      primary: primaryDark,
      primaryContainer: Color(0xFF134E4A),
      secondary: accentSky,
      error: emergencyRed,
      surface: Color(0xFF111827),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Color(0xFFF1F5F9),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    brightness: Brightness.dark,
  );
}
