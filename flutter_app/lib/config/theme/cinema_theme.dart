import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Cinema-Theme v2 — Hyperrealistic Tageszeit-adaptive Ambient-Stimmung.
///
/// V2 unterschiede zu v1:
///   * 5-stop Background-Mesh-Gradient (statt 3) + 2 sekundäre Radial-Hotspots
///   * Alle Phasen haben Light-Leaks (vorher nur Dawn/Dusk)
///   * Sky-Body (Sonne/Mond) als sichtbare animierte Disc pro Phase
///   * Lens-Flare bei Dawn/Dusk
///   * Tint-Opacity um 2× erhöht (immer noch unter WCAG-Grenze)
///   * Vignette dramatischer (bis 0.60 Nacht)
///   * Chromatic-Aberration-Aktivierung pro Phase (Nacht + Dusk)
///   * Intensity-Multiplier via CinemaIntensity (full/reduced/off)
///
/// Brand-Farben (Bronze, Amber, Herzrot) bleiben STATISCH.
enum CinemaPhase {
  /// 23–05 Uhr — Tiefes Indigo, kalter Mond, Sternenlicht
  night,
  /// 05–08 Uhr — Lavendel zu Pfirsich, aufgehende Sonne
  dawn,
  /// 08–12 Uhr — Warmes Tageslicht, hohe Sonne links
  morning,
  /// 12–17 Uhr — Klar, lebendig, neutrale Sonne mittig
  day,
  /// 17–20 Uhr — Hyperreal Sunset, sinkende Sonne rechts
  dusk,
  /// 20–23 Uhr — Bronze + tiefes Aubergine, aufgehender Mond
  evening,
}

/// Phase-Spezifikation — alle Cinema-Effekte parametrisiert.
class CinemaPhaseSpec {
  const CinemaPhaseSpec({
    required this.label,
    required this.emoji,
    required this.bgStops,
    required this.bgStopPositions,
    required this.meshHotspots,
    required this.tintColor,
    required this.tintOpacity,
    required this.vignetteIntensity,
    required this.grainOpacity,
    required this.leakSpots,
    required this.skyBody,
    this.lensFlare,
    this.chromaticAberration = 0.0,
  });

  final String label;
  final String emoji;

  /// 5 Gradient-Stops für den Mesh-Hintergrund.
  final List<Color> bgStops;

  /// 5 Stop-Positionen (0.0–1.0), gleiche Länge wie bgStops.
  final List<double> bgStopPositions;

  /// Sekundäre Radial-"Hotspots" — werden über dem Haupt-Gradient gelegt
  /// (BlendMode.plus) und erzeugen den echten Mesh-Look.
  final List<MeshHotspot> meshHotspots;

  /// Phase-spezifischer Tint, BlendMode.overlay.
  final Color tintColor;

  /// 0.0 – 0.25 (max 25% damit Brand-Farben lesbar bleiben).
  final double tintOpacity;

  /// 0.0 – 0.65. Nacht ~0.60, Tag ~0.20.
  final double vignetteIntensity;

  /// 0.0 – 0.05. Film-Grain-Rauschen.
  final double grainOpacity;

  /// Light-Leaks — warme/kühle Lichtflecken am Rand.
  final List<LightLeakSpot> leakSpots;

  /// Sonne oder Mond — sichtbare Disc mit Bloom.
  final SkyBodySpec skyBody;

  /// Optional: Lens-Flare-Element (typisch Dawn/Dusk).
  final LensFlareSpec? lensFlare;

  /// 0.0–4.0 px Pixel-Shift für Chromatic-Aberration am Bildschirmrand.
  final double chromaticAberration;
}

/// Sekundärer Radial-Hotspot über dem Haupt-Gradient — wirkt wie
/// echte Wolken/Atmosphäre. Mehrere übereinander = Mesh-Look.
class MeshHotspot {
  const MeshHotspot({
    required this.alignment,
    required this.color,
    required this.radius,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;

  /// Radius als Anteil der kürzeren Bildschirmseite (0.0–2.0).
  final double radius;

  /// 0.0–0.7.
  final double opacity;
}

/// Light-Leak — weicher Lichtfleck am Bildschirmrand.
class LightLeakSpot {
  const LightLeakSpot({
    required this.alignment,
    required this.color,
    required this.radius,
    required this.opacity,
    this.pulse = false,
  });

  final Alignment alignment;
  final Color color;
  final double radius;
  final double opacity;

  /// Wenn true, pulsiert der Leak langsam (4s breath).
  final bool pulse;
}

/// Sonne/Mond — sichtbare Disc mit Bloom-Glow am Bildschirmrand.
class SkyBodySpec {
  const SkyBodySpec({
    required this.alignment,
    required this.diameter,
    required this.core,
    required this.glow,
    required this.isMoon,
  });

  /// Position am Bildschirm.
  final Alignment alignment;

  /// Kerndurchmesser in dp.
  final double diameter;

  /// Innerer Kern-Farbton.
  final Color core;

  /// Äußerer Glow-Farbton.
  final Color glow;

  /// Wenn true → Mond (mit Krater-Look + kühlerem Glow).
  final bool isMoon;
}

/// Klassisches Lens-Flare — 4-Strahl-Stern + Highlight-Ring + 2 Linsen-Ghosts.
class LensFlareSpec {
  const LensFlareSpec({
    required this.alignment,
    required this.color,
    required this.intensity,
  });

  /// Position der Hauptlichtquelle (üblicherweise = SkyBody.alignment).
  final Alignment alignment;

  /// Stern-Farbe.
  final Color color;

  /// 0.0–1.0.
  final double intensity;
}

/// Zentrale Lookup-Tabelle aller Cinema-Phasen — v2 Hyperreal.
class CinemaTheme {
  const CinemaTheme._();

  static const Map<CinemaPhase, CinemaPhaseSpec> specs = {
    // ── NACHT — tiefes Indigo, Mond, Sterne ────────────────────────
    CinemaPhase.night: CinemaPhaseSpec(
      label: 'Nacht',
      emoji: '🌌',
      bgStops: [
        Color(0xFF02040A),
        Color(0xFF050918),
        Color(0xFF0A1228),
        Color(0xFF0E1838),
        Color(0xFF030712),
      ],
      bgStopPositions: [0.0, 0.25, 0.5, 0.75, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(-0.6, -0.7),
          color: Color(0xFF1E2B5E),
          radius: 1.1,
          opacity: 0.55,
        ),
        MeshHotspot(
          alignment: Alignment(0.8, 0.5),
          color: Color(0xFF120B3A),
          radius: 0.9,
          opacity: 0.40,
        ),
      ],
      tintColor: Color(0xFF2A3469),
      tintOpacity: 0.10,
      vignetteIntensity: 0.60,
      grainOpacity: 0.045,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(-0.95, -0.95),
          color: Color(0xFF4A5BFF),
          radius: 0.35,
          opacity: 0.18,
          pulse: true,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(0.7, -0.85),
        diameter: 110,
        core: Color(0xFFF5F3FF),
        glow: Color(0xFF8FB8FF),
        isMoon: true,
      ),
      chromaticAberration: 1.5,
    ),

    // ── DAWN — Lavendel zu Pfirsich, aufgehende Sonne ─────────────
    CinemaPhase.dawn: CinemaPhaseSpec(
      label: 'Morgendämmerung',
      emoji: '🌅',
      bgStops: [
        Color(0xFF1A1530),
        Color(0xFF35234A),
        Color(0xFF5C2D45),
        Color(0xFF8A3B3E),
        Color(0xFFB85E40),
      ],
      bgStopPositions: [0.0, 0.25, 0.5, 0.75, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(0.85, 0.7),
          color: Color(0xFFFDBA74),
          radius: 1.2,
          opacity: 0.50,
        ),
        MeshHotspot(
          alignment: Alignment(-0.7, -0.8),
          color: Color(0xFF6D4B82),
          radius: 0.9,
          opacity: 0.45,
        ),
      ],
      tintColor: Color(0xFFFB923C),
      tintOpacity: 0.18,
      vignetteIntensity: 0.32,
      grainOpacity: 0.035,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(0.95, 0.85),
          color: Color(0xFFFDBA74),
          radius: 0.65,
          opacity: 0.42,
          pulse: true,
        ),
        LightLeakSpot(
          alignment: Alignment(-0.9, 0.95),
          color: Color(0xFFEC4899),
          radius: 0.40,
          opacity: 0.22,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(0.8, 0.85),
        diameter: 140,
        core: Color(0xFFFFF7ED),
        glow: Color(0xFFFB923C),
        isMoon: false,
      ),
      lensFlare: LensFlareSpec(
        alignment: Alignment(0.8, 0.85),
        color: Color(0xFFFED7AA),
        intensity: 0.7,
      ),
      chromaticAberration: 1.2,
    ),

    // ── MORNING — Tageslicht, hohe Sonne, klarer Himmel ───────────
    CinemaPhase.morning: CinemaPhaseSpec(
      label: 'Vormittag',
      emoji: '☀️',
      bgStops: [
        Color(0xFF1B2A45),
        Color(0xFF223C5E),
        Color(0xFF2F5379),
        Color(0xFF4378A0),
        Color(0xFF6F9FBE),
      ],
      bgStopPositions: [0.0, 0.3, 0.55, 0.8, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(-0.5, -0.85),
          color: Color(0xFFFCD34D),
          radius: 0.95,
          opacity: 0.32,
        ),
        MeshHotspot(
          alignment: Alignment(0.6, 0.4),
          color: Color(0xFF7DD3FC),
          radius: 1.1,
          opacity: 0.30,
        ),
      ],
      tintColor: Color(0xFF7DD3FC),
      tintOpacity: 0.12,
      vignetteIntensity: 0.20,
      grainOpacity: 0.025,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(-0.5, -0.92),
          color: Color(0xFFFCD34D),
          radius: 0.45,
          opacity: 0.30,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(-0.5, -0.88),
        diameter: 95,
        core: Color(0xFFFFFBEB),
        glow: Color(0xFFFCD34D),
        isMoon: false,
      ),
      chromaticAberration: 0.5,
    ),

    // ── DAY — Klar, lebendig ───────────────────────────────────────
    CinemaPhase.day: CinemaPhaseSpec(
      label: 'Tag',
      emoji: '🏙️',
      bgStops: [
        Color(0xFF1F3050),
        Color(0xFF2A4068),
        Color(0xFF345080),
        Color(0xFF466CA1),
        Color(0xFF648AC0),
      ],
      bgStopPositions: [0.0, 0.3, 0.55, 0.8, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(0.0, -0.95),
          color: Color(0xFFFFFFFF),
          radius: 0.85,
          opacity: 0.25,
        ),
        MeshHotspot(
          alignment: Alignment(-0.7, 0.5),
          color: Color(0xFF60A5FA),
          radius: 1.0,
          opacity: 0.28,
        ),
      ],
      tintColor: Color(0xFFE5E7EB),
      tintOpacity: 0.08,
      vignetteIntensity: 0.18,
      grainOpacity: 0.020,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(0.0, -0.95),
          color: Color(0xFFFFFFFF),
          radius: 0.35,
          opacity: 0.18,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(0.05, -0.92),
        diameter: 80,
        core: Color(0xFFFFFFFF),
        glow: Color(0xFFFEF3C7),
        isMoon: false,
      ),
      chromaticAberration: 0.3,
    ),

    // ── DUSK — Hyperreal Sunset, sinkende Sonne, Highlight-Phase ──
    CinemaPhase.dusk: CinemaPhaseSpec(
      label: 'Abenddämmerung',
      emoji: '🌇',
      bgStops: [
        Color(0xFF2A1228),
        Color(0xFF541B2A),
        Color(0xFF8E2B2A),
        Color(0xFFC8462A),
        Color(0xFFE87838),
      ],
      bgStopPositions: [0.0, 0.25, 0.5, 0.75, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(0.9, 0.7),
          color: Color(0xFFFDBA74),
          radius: 1.4,
          opacity: 0.65,
        ),
        MeshHotspot(
          alignment: Alignment(-0.8, -0.5),
          color: Color(0xFF7C2D12),
          radius: 1.0,
          opacity: 0.55,
        ),
      ],
      tintColor: Color(0xFFF59E0B),
      tintOpacity: 0.22,
      vignetteIntensity: 0.30,
      grainOpacity: 0.040,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(-0.95, 0.7),
          color: Color(0xFFC79363),
          radius: 0.70,
          opacity: 0.55,
        ),
        LightLeakSpot(
          alignment: Alignment(0.98, 0.95),
          color: Color(0xFFF59E0B),
          radius: 0.50,
          opacity: 0.45,
          pulse: true,
        ),
        LightLeakSpot(
          alignment: Alignment(0.4, -0.95),
          color: Color(0xFFDB2777),
          radius: 0.30,
          opacity: 0.20,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(0.85, 0.7),
        diameter: 170,
        core: Color(0xFFFFEDD5),
        glow: Color(0xFFF59E0B),
        isMoon: false,
      ),
      lensFlare: LensFlareSpec(
        alignment: Alignment(0.85, 0.7),
        color: Color(0xFFFED7AA),
        intensity: 1.0,
      ),
      chromaticAberration: 2.5,
    ),

    // ── EVENING — Bronze + Aubergine, aufgehender Mond ────────────
    CinemaPhase.evening: CinemaPhaseSpec(
      label: 'Abend',
      emoji: '🌃',
      bgStops: [
        Color(0xFF120822),
        Color(0xFF20142E),
        Color(0xFF3A1F45),
        Color(0xFF52294E),
        Color(0xFF6B3852),
      ],
      bgStopPositions: [0.0, 0.25, 0.5, 0.75, 1.0],
      meshHotspots: [
        MeshHotspot(
          alignment: Alignment(0.6, -0.6),
          color: Color(0xFF8B4513),
          radius: 1.0,
          opacity: 0.50,
        ),
        MeshHotspot(
          alignment: Alignment(-0.8, 0.7),
          color: Color(0xFF3B1B47),
          radius: 0.9,
          opacity: 0.45,
        ),
      ],
      tintColor: Color(0xFFA0763A),
      tintOpacity: 0.16,
      vignetteIntensity: 0.45,
      grainOpacity: 0.035,
      leakSpots: [
        LightLeakSpot(
          alignment: Alignment(0.95, -0.4),
          color: Color(0xFFC79363),
          radius: 0.45,
          opacity: 0.35,
          pulse: true,
        ),
        LightLeakSpot(
          alignment: Alignment(-0.95, 0.95),
          color: Color(0xFF6D28D9),
          radius: 0.40,
          opacity: 0.20,
        ),
      ],
      skyBody: SkyBodySpec(
        alignment: Alignment(-0.8, -0.85),
        diameter: 100,
        core: Color(0xFFFFFBEB),
        glow: Color(0xFFC79363),
        isMoon: true,
      ),
      chromaticAberration: 2.0,
    ),
  };

  /// Stunde-basierte Phase-Bestimmung.
  static CinemaPhase resolveForTime(DateTime t) {
    final h = t.hour;
    if (h >= 23 || h < 5) return CinemaPhase.night;
    if (h < 8) return CinemaPhase.dawn;
    if (h < 12) return CinemaPhase.morning;
    if (h < 17) return CinemaPhase.day;
    if (h < 20) return CinemaPhase.dusk;
    return CinemaPhase.evening;
  }

  static CinemaPhaseSpec specFor(CinemaPhase p) => specs[p]!;
}

/// User-Override für Cinema-Phase.
enum CinemaMode {
  auto,
  off,
  forceNight,
  forceDay,
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

/// Effektstärke-Multiplier — Battery-Saver-Option.
enum CinemaIntensity {
  /// 100 % aller Effekte (Default).
  full,
  /// 50 % aller Effekte (Battery-Saver, ältere Geräte).
  reduced,
  /// 0 % aller Effekte (nur statischer Hintergrund).
  minimal,
}

extension CinemaIntensityX on CinemaIntensity {
  double get multiplier {
    switch (this) {
      case CinemaIntensity.full:    return 1.0;
      case CinemaIntensity.reduced: return 0.5;
      case CinemaIntensity.minimal: return 0.0;
    }
  }

  String get label {
    switch (this) {
      case CinemaIntensity.full:    return 'Volle Intensität';
      case CinemaIntensity.reduced: return 'Reduziert (50 %)';
      case CinemaIntensity.minimal: return 'Minimal (nur Hintergrund)';
    }
  }

  String get key {
    switch (this) {
      case CinemaIntensity.full:    return 'full';
      case CinemaIntensity.reduced: return 'reduced';
      case CinemaIntensity.minimal: return 'minimal';
    }
  }

  static CinemaIntensity fromKey(String? key) {
    switch (key) {
      case 'reduced': return CinemaIntensity.reduced;
      case 'minimal': return CinemaIntensity.minimal;
      case 'full':
      default:        return CinemaIntensity.full;
    }
  }
}
