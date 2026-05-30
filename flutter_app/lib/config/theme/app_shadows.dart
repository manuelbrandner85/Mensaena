import 'package:flutter/material.dart';

import 'app_colors.dart';

/// SKILL: mensaena-design
/// Schatten-Tokens. Cinema-Dark setzt Glows statt Drop-Shadows, weil
/// klassische Shadows auf dunklem Grund nicht funktionieren.
class AppShadows {
  const AppShadows._();

  /// Sanfter Schatten fuer Hover/Lift auf Cards.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Card-Default (subtiler als soft).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Stärkere Tiefe für Sheets/Overlays/Floating-Elemente.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 30,
      spreadRadius: -2,
      offset: Offset(0, 10),
    ),
  ];

  /// Bronze-Glow (Leit-Akzent: FAB, Primär-Buttons im Cinema-Design).
  static List<BoxShadow> bronzeGlow({double intensity = 0.45}) => [
        BoxShadow(
          color: AppColors.bronze.withValues(alpha: intensity),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];

  /// Amber-Glow (Primary-Buttons, Stats).
  static const List<BoxShadow> amberGlow = [
    BoxShadow(
      color: AppColors.amberGlow,
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// Teal-Glow (Sekundaer-CTAs, Trust-Hover).
  static const List<BoxShadow> tealGlow = [
    BoxShadow(
      color: AppColors.tealGlow,
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// Herzrot-Glow (Emergency, Crisis-Buttons).
  static const List<BoxShadow> herzrotGlow = [
    BoxShadow(
      color: AppColors.herzrotGlow,
      blurRadius: 28,
      spreadRadius: -4,
    ),
  ];
}
