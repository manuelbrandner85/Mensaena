import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Cinema-Theme — Tageszeit-adaptive Ambient-Stimmung.
///
/// Brand-Farben (Bronze, Amber, Herzrot) bleiben STATISCH (siehe AppColors).
/// Nur Hintergrund-Gradient, Tint, Vignette, Film-Grain und Light-Leaks
/// shiften je nach Uhrzeit — wie ein Film mit Color-Grading je Szene.
enum CinemaPhase {
  /// 23–05 Uhr — Tiefes Indigo, kühl, ruhig
  night,
  /// 05–08 Uhr — Lavendel zu Pfirsich, sanftes Aufwachen
  dawn,
  /// 08–12 Uhr — Warmes Tageslicht, optimistisch
  morning,
  /// 12–17 Uhr — Klar, lebendig, neutral
  day,
  /// 17–20 Uhr — Hyperreal Sunset, Hauptmoment
  dusk,
  /// 20–23 Uhr — Bronze + tiefes Aubergine, kinoreif
  evening,
}

/// Phase-Spezifikation — alle 6 Cinema-Effekte parametrisiert.
class CinemaPhaseSpec {
  const CinemaPhaseSpec({
    required this.label,
    required this.emoji,
    required this.bgStops,
    required this.tintColor,
    required this.tintOpacity,
    required this.vignetteIntensity,
    required this.grainOpacity,
    required this.leakSpots,
  });

  /// Anzeigename im Settings-Preview (z.B. "Abenddämmerung").
  final String label;

  /// Emoji für UI-Indicator.
  final String emoji;

  /// 3 Gradient-Stops fuer den Mesh-Hintergrund (top-left → center → bottom-right).
  final List<Color> bgStops;

  /// Phase-spezifischer Tint, wird als overlay-BlendMode aufgelegt.
  final Color tintColor;

  /// 0.0 – 0.12 (max 12% damit Brand-Farben nicht ueberlagert werden).
  final double tintOpacity;

  /// 0.0 (kein) – 0.5 (sehr dunkler Rand). Nacht ~0.4, Tag ~0.05.
  final double vignetteIntensity;

  /// 0.0 – 0.03. Film-Grain-Rauschen.
  final double grainOpacity;

  /// Liste von Light-Leaks (warme Lichtflecken am Rand). Leer = aus.
  final List<LightLeakSpot> leakSpots;
}

/// Ein Light-Leak — warmer Lichtfleck am Bildschirmrand (Sonnenstand-Anlehnung).
class LightLeakSpot {
  const LightLeakSpot({
    required this.alignment,
    required this.color,
    required this.radius,
    required this.opacity,
  });

  /// Position am Bildschirm (Alignment.topLeft = Sonnenaufgang etc.).
  final Alignment alignment;

  /// Warm-Color (Amber/Bronze).
  final Color color;

  /// Radius des Lichtflecks als Faktor der Bildschirmgröße (0.0 – 1.0).
  final double radius;

  /// 0.0 – 0.5
  final double opacity;
}

/// Zentrale Lookup-Tabelle aller Cinema-Phasen.
class CinemaTheme {
  const CinemaTheme._();

  static const Map<CinemaPhase, CinemaPhaseSpec> specs = {
    CinemaPhase.night: CinemaPhaseSpec(
      label: 'Nacht',
      emoji: '🌌',
      bgStops: [
        Color(0xFF05080F),
        Color(0xFF080C18),
        Color(0xFF0A0F1C),
      ],
      tintColor: Color(0xFF1A1F3D), // Indigo
      tintOpacity: 0.05,
      vignetteIntensity: 0.40,
      grainOpacity: 0.025,
      leakSpots: [],
    ),
    CinemaPhase.dawn: CinemaPhaseSpec(
      label: 'Morgendämmerung',
      emoji: '🌅',
      bgStops: [
        Color(0xFF1A1530),
        Color(0xFF2D2438),
        Color(0xFF4A2B3A),
      ],
      tintColor: Color(0xFFE8A788), // Rose-Peach
      tintOpacity: 0.08,
      vignetteIntensity: 0.20,
      grainOpacity: 0.020,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(0.9, -0.8),
          color: Color(0xFFFBBF24),
          radius: 0.45,
          opacity: 0.25,
        ),
      ],
    ),
    CinemaPhase.morning: CinemaPhaseSpec(
      label: 'Vormittag',
      emoji: '☀️',
      bgStops: [
        Color(0xFF1E2A3E),
        Color(0xFF243553),
        Color(0xFF2A3D5C),
      ],
      tintColor: Color(0xFF7DD3FC), // Sky-Cyan
      tintOpacity: 0.05,
      vignetteIntensity: 0.12,
      grainOpacity: 0.018,
      leakSpots: [],
    ),
    CinemaPhase.day: CinemaPhaseSpec(
      label: 'Tag',
      emoji: '🏙️',
      bgStops: [
        Color(0xFF22304A),
        Color(0xFF273858),
        Color(0xFF2D4068),
      ],
      tintColor: Color(0xFFCBD5E1), // Ink-Soft (neutral hell)
      tintOpacity: 0.03,
      vignetteIntensity: 0.08,
      grainOpacity: 0.015,
      leakSpots: [],
    ),
    CinemaPhase.dusk: CinemaPhaseSpec(
      label: 'Abenddämmerung',
      emoji: '🌇',
      bgStops: [
        Color(0xFF3A1F1A),
        Color(0xFF5E2D2A),
        Color(0xFF7C4030),
      ],
      tintColor: Color(0xFFF59E0B), // Amber-Glow
      tintOpacity: 0.10,
      vignetteIntensity: 0.18,
      grainOpacity: 0.022,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(-0.9, 0.6),
          color: Color(0xFFC79363),
          radius: 0.55,
          opacity: 0.30,
        ),
        LightLeakSpot(
          alignment: Alignment(0.95, 0.95),
          color: Color(0xFFF59E0B),
          radius: 0.35,
          opacity: 0.18,
        ),
      ],
    ),
    CinemaPhase.evening: CinemaPhaseSpec(
      label: 'Abend',
      emoji: '🌃',
      bgStops: [
        Color(0xFF1B1428),
        Color(0xFF221B33),
        Color(0xFF2A1E3D),
      ],
      tintColor: Color(0xFF7C4A1F), // Bronze-Deep
      tintOpacity: 0.06,
      vignetteIntensity: 0.28,
      grainOpacity: 0.022,
      leakSpots: [],
    ),
  };

  /// Stunde-basierte Phase-Bestimmung.
  /// 23–05 night, 05–08 dawn, 08–12 morning, 12–17 day, 17–20 dusk, 20–23 evening.
  static CinemaPhase resolveForTime(DateTime t) {
    final h = t.hour;
    if (h >= 23 || h < 5) return CinemaPhase.night;
    if (h < 8) return CinemaPhase.dawn;
    if (h < 12) return CinemaPhase.morning;
    if (h < 17) return CinemaPhase.day;
    if (h < 20) return CinemaPhase.dusk;
    return CinemaPhase.evening;
  }

  /// Spec fuer eine Phase.
  static CinemaPhaseSpec specFor(CinemaPhase p) => specs[p]!;
}

/// User-Override fuer Cinema-Theme.
enum CinemaMode {
  /// Automatisch nach Uhrzeit (Default).
  auto,
  /// Komplett deaktiviert — pures Cinema-Dark, keine Effekte.
  off,
  /// Force night (alle Bildschirme im Nacht-Theme).
  forceNight,
  /// Force day (alle Bildschirme im Tag-Theme).
  forceDay,
  /// Force dusk (Lieblings-Phase fuer Sunset-Lover).
  forceDusk,
}

extension CinemaModeX on CinemaMode {
  String get label {
    switch (this) {
      case CinemaMode.auto:       return 'Automatisch';
      case CinemaMode.off:        return 'Aus';
      case CinemaMode.forceNight: return 'Immer Nacht';
      case CinemaMode.forceDay:   return 'Immer Tag';
      case CinemaMode.forceDusk:  return 'Immer Sunset';
    }
  }

  String get key {
    switch (this) {
      case CinemaMode.auto:       return 'auto';
      case CinemaMode.off:        return 'off';
      case CinemaMode.forceNight: return 'force_night';
      case CinemaMode.forceDay:   return 'force_day';
      case CinemaMode.forceDusk:  return 'force_dusk';
    }
  }

  static CinemaMode fromKey(String? key) {
    switch (key) {
      case 'off':         return CinemaMode.off;
      case 'force_night': return CinemaMode.forceNight;
      case 'force_day':   return CinemaMode.forceDay;
      case 'force_dusk':  return CinemaMode.forceDusk;
      case 'auto':
      default:            return CinemaMode.auto;
    }
  }
}
