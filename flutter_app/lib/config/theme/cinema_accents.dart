/// SKILL: mensaena-design
/// Phase-Accents — Cinema-Phase-bewusste Farben für Buttons, Cards, Borders.
///
/// Idee: statt einen Tint ÜBER den Content zu legen (überdeckt Text +
/// macht Buttons schwer lesbar), greifen Cards/Buttons sich AKTIV die
/// Phase-Stimmung ab. Dadurch fühlt sich UI integriert an, ohne dass
/// die Brand-Identität (Bronze/Amber) verschwindet.
///
/// Strategie:
///   * Brand-Farben (Bronze, Amber, Herzrot, Teal, Leben) bleiben Identität.
///   * Phase-Akzent ist ein subtiles Color.lerp(brand, phaseHue, 0.15–0.25)
///     — wirkt wie ein Filter, der das Licht der Tageszeit aufnimmt,
///     ohne die Identität zu killen.
///   * Glow-Farben werden phasen-passend tonisiert (Bronze-Glow bei Dusk
///     wird orange-warmer, bei Night kühler).
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'cinema_theme.dart';

class CinemaAccents {
  const CinemaAccents._();

  /// Akzent-Farbe der Phase (für Borders, Glows, Highlights).
  /// Subtil, nicht zu sättigungsstark.
  static Color hue(CinemaPhase? phase) {
    if (phase == null) return AppColors.bronze;
    switch (phase) {
      case CinemaPhase.night:     return const Color(0xFF6B7CFF); // cool indigo
      case CinemaPhase.dawn:      return const Color(0xFFFB923C); // peach
      case CinemaPhase.morning:   return const Color(0xFFFCD34D); // soft gold
      case CinemaPhase.day:       return const Color(0xFF93C5FD); // sky
      case CinemaPhase.dusk:      return const Color(0xFFFB923C); // warm orange
      case CinemaPhase.evening:   return const Color(0xFFC79363); // bronze warm
    }
  }

  /// Akzent-Glow (für PulseBloom + BoxShadow).
  static Color glow(CinemaPhase? phase) {
    if (phase == null) return AppColors.amberGlow;
    switch (phase) {
      case CinemaPhase.night:     return const Color(0xFF4A5BFF);
      case CinemaPhase.dawn:      return const Color(0xFFFB923C);
      case CinemaPhase.morning:   return const Color(0xFFFBBF24);
      case CinemaPhase.day:       return const Color(0xFFFFFFFF);
      case CinemaPhase.dusk:      return const Color(0xFFF59E0B);
      case CinemaPhase.evening:   return const Color(0xFFC79363);
    }
  }

  /// Card-Border, sehr subtil — bekommt einen 18 %-Touch der Phase-Hue.
  static Color cardBorder(CinemaPhase? phase) {
    const base = AppColors.line;
    final h = hue(phase);
    return Color.lerp(base, h, 0.30) ?? base;
  }

  /// Card-Background — kleiner Phase-Touch auf den dunklen Surface.
  static Color cardSurface(CinemaPhase? phase) {
    const base = AppColors.surface;
    final h = hue(phase);
    return Color.lerp(base, h, 0.05) ?? base;
  }

  /// Lerp Brand-Color leicht in Richtung Phase.
  /// `strength` 0.0 = pure brand, 1.0 = pure phase. Default 0.18.
  static Color tinted(Color brand, CinemaPhase? phase,
      {double strength = 0.18}) {
    if (phase == null) return brand;
    return Color.lerp(brand, hue(phase), strength) ?? brand;
  }
}
