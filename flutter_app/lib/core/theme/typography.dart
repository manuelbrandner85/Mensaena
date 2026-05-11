import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Cinema-Typografie:
/// - Display (DM Serif Display): Headlines, Hero-Titel, editorial.
/// - Body (Inter): UI, Texte, Buttons, alles Funktionale.
/// - Mono (JetBrains Mono): Zahlen, Stats, Timestamps, Code.
/// - Label (Inter, uppercase, tracking): Kategorie-Pillen, Sektionslabels.
class MnTypography {
  const MnTypography._();

  // ── Display (Serifenschrift, editorial) ───────────────────────────────
  static TextStyle display({
    double size = 28,
    Color color = MnColors.ink,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = -0.03,
    double? height,
    List<Shadow>? shadows,
  }) => GoogleFonts.dmSerifDisplay(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing * size,
        height: height,
        shadows: shadows,
      );

  // ── Body (Inter, Standard) ────────────────────────────────────────────
  static TextStyle body({
    double size = 15,
    Color color = MnColors.inkSoft,
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
    double? letterSpacing,
  }) => GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ── Mono (JetBrains, Zahlen/Stats) ────────────────────────────────────
  static TextStyle mono({
    double size = 14,
    Color color = MnColors.amber,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
  }) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  // ── Label (uppercase, tracking, klein) ────────────────────────────────
  static TextStyle label({
    double size = 12,
    Color color = MnColors.mute,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.05,
  }) => GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing * size,
      );

  // ── AppBar-Titel (wide-tracked Inter) ─────────────────────────────────
  static TextStyle appBarTitle({Color color = MnColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 17,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 5.0,
        shadows: const [
          Shadow(color: MnColors.amberGlow, blurRadius: 20),
        ],
      );

  // ── Helper fuer Subtitles/Captions ────────────────────────────────────
  static TextStyle caption({Color color = MnColors.mute}) =>
      body(size: 12, color: color, height: 1.4);
}
