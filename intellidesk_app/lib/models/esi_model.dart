import 'package:flutter/material.dart';

class EsiModel {
  final String level;
  final String label;
  final double csiThreshold;
  final Color color;

  const EsiModel({
    required this.level,
    required this.label,
    required this.csiThreshold,
    required this.color,
  });

  static const List<EsiModel> levels = [
    EsiModel(
      level: 'ESI-1',
      label: 'Resuscitation / Critical',
      csiThreshold: 0.85,
      color: Color(0xFFEF4444),
    ),
    EsiModel(
      level: 'ESI-2',
      label: 'Emergent / High Distress',
      csiThreshold: 0.60,
      color: Color(0xFFF97316),
    ),
    EsiModel(
      level: 'ESI-3',
      label: 'Urgent / Routine Copay',
      csiThreshold: 0.0,
      color: Color(0xFF0D9488),
    ),
  ];

  static EsiModel fromCsi(double csi) {
    if (csi >= 0.85) return levels[0];
    if (csi >= 0.60) return levels[1];
    return levels[2];
  }
}
