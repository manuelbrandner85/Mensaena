import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// SKILL: mensaena-design
/// Typographie matched zur Live-Webseite (src/app/layout.tsx):
/// - Instrument Serif: h1/h2/h3 (Cinema-Editorial)
/// - Fraunces: Display-Backup, Wordmarks
/// - Inter: Body, UI, Buttons
/// - JetBrains Mono: Zahlen, Stats, Code, Timestamps
///
/// Premium-Pass (A6): Mono + Label nutzen jetzt `tabularFigures` —
/// gleichbreite Ziffern, sodass Stats-Tabellen, Counter, Preise und
/// Timestamps exakt untereinander stehen (Bloomberg-Look). Display-Serif
/// nutzt `liningFigures` für editorialer Großziffern-Optik.
class AppTypography {
  const AppTypography._();

  // Re-usable Feature-Listen. const damit kein Realloc pro Aufruf.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];
  static const List<FontFeature> _lining = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

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
        fontFeatures: _lining,
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
        fontFeatures: _lining,
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

  /// Zahlen, Stats, Code, Timestamps. Tabular-Figures sorgen für exakt
  /// gleichbreite Ziffern → Tabellen/Counter richten sich aus.
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
        fontFeatures: _tabular,
      );

  /// Bloomberg-Style Hero-Zahl. Riesig, fett, mono, tabular — für die
  /// Headline-Stats im Admin-Dashboard, Trust-Score, Karma, etc. Eigene
  /// semantische API damit der "1-Mio-€-Look" überall konsistent ist.
  static TextStyle stat({
    double size = 44,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = -1.5,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.0,
        fontFeatures: _tabular,
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
        fontFeatures: _tabular,
      );

  /// AppBar-Titel — Design (Cinema-Hyperreal): editorialer Instrument-Serif
  /// statt weit-getrackerter Inter (.appbar .title font-family Instrument Serif).
  static TextStyle appBarTitle({Color color = AppColors.ink}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 23,
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        fontFeatures: _lining,
      );

  /// Helper fuer Subtitles/Captions.
  static TextStyle caption({Color color = AppColors.mute}) =>
      body(size: 12, color: color, height: 1.4);
}
