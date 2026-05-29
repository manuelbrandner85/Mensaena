import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// SKILL: mensaena-design
/// Typographie matched zur Live-Webseite (src/app/layout.tsx):
/// - Instrument Serif: h1/h2/h3 (Cinema-Editorial)
/// - Fraunces: Display-Backup, Wordmarks
/// - Inter: Body, UI, Buttons
/// - JetBrains Mono: Zahlen, Stats, Code, Timestamps
class AppTypography {
  const AppTypography._();

  /// Cinema-Editorial Headlines (Web-Klasse: h1/h2/h3).
  static TextStyle display({
    double size = 28,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = -0.02,
    double? height,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing * size,
        height: height,
        shadows: shadows,
      );

  /// Display-Backup / Wordmark (Cinema-Display-Variable Font).
  static TextStyle frauncesDisplay({
    double size = 32,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = -0.025,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing * size,
        height: height,
      );

  /// Standard-Text (UI, Buttons, Paragraphs).
  static TextStyle body({
    double size = 15,
    Color color = AppColors.inkSoft,
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Zahlen, Stats, Code, Timestamps.
  static TextStyle mono({
    double size = 14,
    Color color = AppColors.amber,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  /// Uppercase Labels (Kategorie-Pillen, Eyebrows, Section-Labels).
  /// Design (Cinema-Hyperreal): Eyebrows/Nav/Chips sind durchgängig
  /// Monospace mit weitem Tracking → JetBrains Mono statt Inter.
  static TextStyle label({
    double size = 12,
    Color color = AppColors.mute,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0.16,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing * size,
      );

  /// AppBar-Titel (wide-tracked Inter mit subtilem Amber-Glow).
  static TextStyle appBarTitle({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 17,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 5.0,
        shadows: const [
          Shadow(color: AppColors.amberGlow, blurRadius: 20),
        ],
      );

  /// Helper fuer Subtitles/Captions.
  static TextStyle caption({Color color = AppColors.mute}) =>
      body(size: 12, color: color, height: 1.4);
}
