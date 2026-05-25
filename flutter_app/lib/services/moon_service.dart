/// SKILL: mensaena-features
/// Moon-Service (F60): berechnet aktuelle Mondphase + Beleuchtungs-%
/// aus dem aktuellen Datum — kein API noetig, rein Astronomie-Math.
///
/// Algorithmus: synodische Periode 29.530588853 Tage seit Referenz-Neumond
/// (2000-01-06 18:14 UTC). Genauigkeit ±1 Tag fuer normale UX-Zwecke ok.
library;

import 'dart:math' as math;

enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

class MoonInfo {
  const MoonInfo({
    required this.phase,
    required this.illumination,
    required this.ageDays,
  });

  final MoonPhase phase;

  /// 0.0 = Neumond, 1.0 = Vollmond
  final double illumination;

  /// Tage seit letztem Neumond, 0..29.53.
  final double ageDays;

  String get emoji {
    switch (phase) {
      case MoonPhase.newMoon:
        return '🌑';
      case MoonPhase.waxingCrescent:
        return '🌒';
      case MoonPhase.firstQuarter:
        return '🌓';
      case MoonPhase.waxingGibbous:
        return '🌔';
      case MoonPhase.fullMoon:
        return '🌕';
      case MoonPhase.waningGibbous:
        return '🌖';
      case MoonPhase.lastQuarter:
        return '🌗';
      case MoonPhase.waningCrescent:
        return '🌘';
    }
  }

  String get labelKey {
    switch (phase) {
      case MoonPhase.newMoon:
        return 'moon.newMoon';
      case MoonPhase.waxingCrescent:
        return 'moon.waxingCrescent';
      case MoonPhase.firstQuarter:
        return 'moon.firstQuarter';
      case MoonPhase.waxingGibbous:
        return 'moon.waxingGibbous';
      case MoonPhase.fullMoon:
        return 'moon.fullMoon';
      case MoonPhase.waningGibbous:
        return 'moon.waningGibbous';
      case MoonPhase.lastQuarter:
        return 'moon.lastQuarter';
      case MoonPhase.waningCrescent:
        return 'moon.waningCrescent';
    }
  }
}

class MoonService {
  const MoonService._();

  static const _synodic = 29.530588853;

  /// Reference Neumond: 2000-01-06 18:14 UTC.
  static final DateTime _ref = DateTime.utc(2000, 1, 6, 18, 14);

  static MoonInfo forDate(DateTime when) {
    final daysSince = when.toUtc().difference(_ref).inSeconds / 86400.0;
    var age = daysSince % _synodic;
    if (age < 0) age += _synodic;
    final phase = _phaseForAge(age);
    // Beleuchtung: (1 - cos(2π * age/synodic)) / 2 — sehr standard.
    final ill = (1 - math.cos((2 * math.pi * age) / _synodic)) / 2;
    return MoonInfo(phase: phase, illumination: ill, ageDays: age);
  }

  static MoonInfo now() => forDate(DateTime.now());

  static MoonPhase _phaseForAge(double age) {
    // 8 Phasen, jede ~3.7 Tage breit; Bestimmungs-Grenzen leicht angepasst,
    // damit New/Full/Quarters ihre kleinen "Snap-Fenster" haben (±1d).
    if (age < 1.0) return MoonPhase.newMoon;
    if (age < 6.4) return MoonPhase.waxingCrescent;
    if (age < 8.4) return MoonPhase.firstQuarter;
    if (age < 13.8) return MoonPhase.waxingGibbous;
    if (age < 15.8) return MoonPhase.fullMoon;
    if (age < 21.1) return MoonPhase.waningGibbous;
    if (age < 23.1) return MoonPhase.lastQuarter;
    if (age < 28.5) return MoonPhase.waningCrescent;
    return MoonPhase.newMoon;
  }
}
