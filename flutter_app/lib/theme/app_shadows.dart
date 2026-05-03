import 'package:flutter/material.dart';

/// Schatten-Definitionen – exakte Übernahme aus globals.css (.shadow-soft, .shadow-card, .shadow-glow).
class AppShadows {
  AppShadows._();

  // shadow-soft: 0 2px 8px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.02)
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  // shadow-card: 0 8px 24px rgba(0,0,0,0.08), 0 2px 4px rgba(0,0,0,0.04)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  // shadow-glow: warmer teal glow
  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x331EAAA6),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> glowTeal = [
    BoxShadow(
      color: Color(0x4D38C4C0),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];
}
