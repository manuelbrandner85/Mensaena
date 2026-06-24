/// SKILL: mensaena-design
/// CinemaOverlay v3 — Lesbarkeit-first.
///
/// ARCHITEKTUR-ÄNDERUNG zu v2:
///   * KEIN Tint mehr ÜBER dem Content (Buttons/Text waren überfärbt).
///   * Atmosphäre vollständig HINTER dem Content:
///     - Background-Mesh-Gradient (5-stop) mit langsamem Drift
///     - Mesh-Hotspots (atmosphärische Wolken)
///     - Atmosphärischer Tiefen-Haze
///     - Starfield (Nacht) / God-Rays (Tag-Phasen) / Ground-Fog
///     - Dust-Particles (Dusk/Evening)
///     - Sky-Body (Sonne/Mond mit Bloom)
///     - Lens-Flare (Dawn/Dusk)
///     - Light-Leaks (Phase-spezifisch)
///   * Über dem Content NUR:
///     - Film-Grain (sehr subtil, Filmlook)
///     - Vignette (nur Eck-Falloff, kein zentraler Verlust)
///     - Chromatic-Aberration (nur Edge-Pixel)
///
/// Phasen-Akzentuierung der UI passiert über CinemaAccents.tinted()
/// (Buttons/Cards greifen sich die Phase aktiv ab, statt überlagert
/// zu werden).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/cinema_theme.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/cinema_provider.dart';
import '../../providers/effects_gate_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/device_tier_service.dart';
import 'atmospheric_layers.dart';
import 'chromatic_aberration.dart';
import 'cinema_parallax.dart';
import 'cinema_weather_layers.dart';
import 'film_grain.dart';
import 'lens_flare.dart';
import 'light_leaks.dart';
import 'sky_body.dart';
import 'vignette.dart';

class CinemaOverlay extends ConsumerWidget {
  const CinemaOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    // EffectsGate statt Einzel-Signale: deckt reduceMotion/seniorMode (none),
    // CinemaIntensity (full/reduced/minimal) UND den Phase-6-Frame-Watchdog
    // ab (full -> reduced bei Jank). intensityFactor (1.0/0.5/0.0) entspricht
    // exakt dem frueheren CinemaIntensity.multiplier — bei reduced fallen die
    // teuren Layer (God-Rays/Flare/Fog/Dust/Grain, Schwelle >= 0.6) weg.
    final profile = ref.watch(effectsProfileProvider);
    final isLight = ref.watch(isLightModeProvider);
    // PERF: Lite-Mode bleibt STRENGER als das Gate (komplett aus statt
    // reduced) — die 9+ AnimationControllers crashten ARM32/Android<9.
    // forceFull-Override hebt die strengere Lite-Mode-Sperre auf, damit der
    // User die vollen Effekte auch auf schwachen Geräten sehen kann.
    final forceFull = ref.watch(forceFullEffectsProvider);
    final liteMode = ref.watch(liteModeActiveProvider) && !forceFull;
    final baseIntensity = profile.intensityFactor;
    // Parallax ist leicht (günstiger Transform) und soll auf JEDEM Gerät
    // laufen, sobald der Schalter an ist — daher unabhängig von isFull/Lite.
    final parallaxOn = ref.watch(cinemaParallaxProvider);

    final reduceMotion = ref.watch(a11yProvider).effectiveReduceMotion;
    // Feinregler (0–100 %) skaliert die atmosphärische Stärke stufenlos.
    final strength = ref.watch(cinemaEffectStrengthProvider) / 100.0;

    // ═══════════ WETTER-ATMOSPHÄRE — eigene, vom Cinema-Master ENTKOPPELTE
    // Ebene. Der Live-Wetter-Hintergrund hat einen EIGENEN Schalter (Default
    // an) und soll laut Design IMMER live sein — unabhängig vom Effekt-Profil,
    // Light-Mode UND davon, ob das übrige Kino läuft. Deshalb VOR dem
    // Cinema-Gate berechnet und (unten) auch dann gerendert, wenn das Kino aus
    // ist (Mode=Aus / A11y / Lite). Vorher hing alles am Early-Return → wer das
    // Kino aus hatte (oder ein Lite-Gerät nutzte), sah NIE Wetter.
    final weatherNow = ref.watch(cinemaWeatherNowProvider).value;
    final weatherBase = weatherTintOf(weatherNow);
    final weatherAdaptiveOn = ref.watch(cinemaWeatherAdaptiveProvider);
    final weatherStrength = weatherAdaptiveOn
        ? (((isLight ? 0.60 : 0.82) * strength).clamp(0.45, 1.0)).toDouble()
        : 0.0;
    // Animierte Wetter-Ebenen (Wolken/Partikel/Schleier/Blitz) haben eigene
    // AnimationController → auf Lite-Geräten (ARM32-Crash-Historie) UND bei
    // A11y-Bewegungsreduktion AUS. Tint/Mood sind reine Farb-Ebenen und laufen
    // auch dort (kein Controller).
    final weatherMotion = weatherAdaptiveOn && !liteMode && !reduceMotion;
    // Echte driftende Wolken bei wolkig/Regen/Schnee/Gewitter. null = klar/Nebel.
    final cloudColor = weatherMotion ? cloudColorOf(weatherNow) : null;
    final cloudDensity = cloudDensityFor(weatherNow);
    // Vordergrund-Regenschleier (Regen/Gewitter).
    final rainVeil = weatherMotion ? rainVeilFor(weatherNow) : null;
    // Gewitter-Stimmung: schwerer, dunkler Top-Tint (reine Farb-Ebene).
    final thunderBase = weatherAdaptiveOn ? thunderMoodColor(weatherNow) : null;
    final thunderMood = thunderBase == null
        ? null
        : Color.lerp(Colors.transparent, thunderBase, weatherStrength);
    final weatherTint = (weatherBase == null || !weatherAdaptiveOn)
        ? null
        : Color.lerp(Colors.transparent, weatherBase, weatherStrength);
    final weather =
        weatherAdaptiveOn ? weatherConditionOf(weatherNow) : CinemaWeather.clear;
    final weatherParticles =
        weatherMotion ? weatherParticleSpec(weatherNow) : null;

    // CRASH-FIX: Off-Mode und On-Mode ergeben strukturell SEHR unterschiedliche
    // Widget-Trees (SizedBox vs RepaintBoundary > Stack > 9+ Controllers). Beim
    // Toggle kann die Disposal-Reihenfolge kollidieren → KeyedSubtree erzwingt
    // sauberen Unmount. Cinema-Master aus (phase==null/Mode=Aus, profile.isOff
    // via A11y/minimal, oder Lite ohne Parallax) → KEIN volles Kino. Die
    // Wetter-Atmosphäre bleibt aber über _weatherOnlyOverlay sichtbar.
    if (phase == null || profile.isOff || (liteMode && !parallaxOn)) {
      return _weatherOnlyOverlay(
        child: child,
        weatherTint: weatherTint,
        thunderMood: thunderMood,
        cloudColor: cloudColor,
        cloudDensity: cloudDensity,
        weather: weather,
        weatherParticles: weatherParticles,
        rainVeil: rainVeil,
        strength: weatherStrength,
        motion: weatherMotion,
      );
    }

    final spec = CinemaTheme.specFor(phase);
    final intensity =
        (isLight ? (baseIntensity * 0.3) : baseIntensity) * strength;
    // Saisonaler Tint (datumsbasiert, keine Netzwerklast).
    final seasonalBase = ref.watch(cinemaSeasonalProvider)
        ? seasonalTintForMonth(DateTime.now().month)
        : null;
    final seasonalTint = seasonalBase == null
        ? null
        : Color.lerp(Colors.transparent, seasonalBase, intensity);
    // B: Echte Sonnen-/Mond-Position (kontinuierlich aus den Sonnenzeiten).
    // null → SkyBody nutzt die statische Phasen-Position (Fallback/Override).
    final skyAlign = ref.watch(cinemaSkyBodyAlignmentProvider).value;
    // C: Wetter-Kondition → animierte Partikel/Nebel/Blitz. D: Saison-Partikel.
    // Teuer (eigener AnimationController) → nur bei vollen Effekten (>= 0.6).
    final heavyOn = intensity >= 0.6;
    // `weather` und `weatherParticles` sind oben (vor dem Cinema-Gate) bereits
    // berechnet — vom Wetter-Schalter abhängig, NICHT von heavyOn.
    // Saison-Partikel nur, wenn KEIN Wetter-Niederschlag aktiv ist (kein
    // Doppel-Schnee) und der Saison-Schalter an ist.
    final seasonalParticles =
        (heavyOn && weatherParticles == null && ref.watch(cinemaSeasonalProvider))
            ? seasonalParticleSpec(DateTime.now().month)
            : null;

    return KeyedSubtree(
      key: const ValueKey('cinema_overlay_on'),
      child: RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
        // ═══════════ BACKGROUND-STACK (alle hinter Content) ═══════════

        // 1. Hintergrund: animierter Mesh-Gradient, in CinemaParallax gewrappt
        // → subtile Neige-Tiefe (nur bei aktivem Parallax-Schalter).
        CinemaParallax(
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(seconds: 8),
              child: _MeshBackground(
                key: ValueKey('mesh_${phase.name}'),
                spec: spec,
              ),
            ),
          ),
        ),

        // 1a2. Saisonaler Tint (Winter/Frühling/Sommer/Herbst).
        if (seasonalTint != null)
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: seasonalTint)),
          ),

        // 1b. Wetter-Tint (Regen/Nebel/Schnee/Gewitter) — eine Farb-Ebene
        // über dem Mesh, passt die Stimmung ans echte Wetter an.
        if (weatherTint != null)
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: weatherTint)),
          ),

        // 1c. Gewitter-Stimmung — zusätzlicher dunkler Top-Down-Tint, der die
        // Szene bei echtem Gewitter schwerer/bedrohlicher macht.
        if (thunderMood != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [thunderMood, Colors.transparent],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
          ),

        // 2. Atmospheric Haze (Tiefen-Eindruck oben→unten)
        RepaintBoundary(
          child: AtmosphericHaze(
            topColor: spec.bgStops.first,
            bottomColor: spec.bgStops.last,
            intensity: intensity,
          ),
        ),

        // 2b. Wetter-Wolken (wolkig/Regen/Schnee/Gewitter) — echte driftende
        // Wolken, damit JEDE Wetterlage sichtbar dem echten Wetter entspricht.
        if (cloudColor != null)
          RepaintBoundary(
            child: CloudDriftLayer(
              color: cloudColor,
              intensity: weatherStrength,
              count: cloudDensity,
            ),
          ),

        // 3. Starfield (Nacht)
        if (spec.hasStarfield)
          RepaintBoundary(child: Starfield(intensity: intensity)),

        // 4. Sky-Body (Sonne/Mond). C3: KEIN AnimatedSwitcher mehr — die
        // SkyBody bleibt persistent (stabiler Key) und animiert den
        // Phasenwechsel selbst als Bogen über den Himmel (Sonne/Mond
        // „wandert" beim Übergang) statt an zwei festen Positionen zu
        // crossfaden. Nur auf full (intensity >= 0.6).
        RepaintBoundary(
          child: SkyBody(
            key: const ValueKey('sky_persistent'),
            spec: spec.skyBody,
            intensity: intensity,
            alignmentOverride: skyAlign,
          ),
        ),

        // 5. God-Rays vom Sky-Body — nur bei full intensity. Strahlt aus der
        // echten Sonnenposition (skyAlign) statt dem statischen Phasen-Punkt.
        if (spec.hasGodRays && intensity >= 0.6)
          RepaintBoundary(
            child: GodRays(
              source: skyAlign ?? spec.skyBody.alignment,
              color: spec.skyBody.glow,
              intensity: intensity * 0.85,
            ),
          ),

        // 6. Lens-Flare — nur bei full intensity.
        if (spec.lensFlare != null && intensity >= 0.6)
          RepaintBoundary(
            child: LensFlare(
              spec: spec.lensFlare!,
              intensity: intensity,
            ),
          ),

        // 7. Light-Leaks
        RepaintBoundary(
          child: LightLeaksOverlay(
            spots: spec.leakSpots,
            intensity: intensity,
          ),
        ),

        // 8. Ground-Fog — nur bei full intensity (animiert, teuer).
        if (spec.hasGroundFog && spec.fogColor != null && intensity >= 0.6)
          RepaintBoundary(
            child: GroundFog(
              color: spec.fogColor!,
              intensity: intensity,
            ),
          ),

        // 9. Dust-Particles — nur bei full intensity (animiert, teuer).
        if (spec.hasDust && spec.dustColor != null && intensity >= 0.6)
          RepaintBoundary(
            child: DustParticles(
              color: spec.dustColor!,
              intensity: intensity,
            ),
          ),

        // 9b. C — Nebel-Drift (Wetter = Nebel): langsam ziehende Schwaden.
        if (weather == CinemaWeather.fog && weatherTint != null)
          RepaintBoundary(
            child: FogDriftLayer(color: weatherTint, intensity: weatherStrength),
          ),

        // 9c. C — Wetter-Partikel (Regen-Schlieren / Schnee-Flocken).
        if (weatherParticles != null)
          RepaintBoundary(
            child: CinemaParticleLayer(
              spec: weatherParticles,
              intensity: weatherStrength,
            ),
          ),

        // 9d. D — Saison-Partikel (Laub/Blüten/Pollen/Schnee), nur ohne Wetter.
        if (seasonalParticles != null)
          RepaintBoundary(
            child: CinemaParticleLayer(
              spec: seasonalParticles,
              intensity: intensity,
            ),
          ),

        // 9e. C — Gewitter-Blitz (gelegentlicher Doppelschlag).
        if (weather == CinemaWeather.thunder && weatherMotion)
          RepaintBoundary(child: LightningFlash(intensity: weatherStrength)),

        // 9f. C — Vordergrund-Regenschleier (Regen/Gewitter): ziehende, weiche
        // Schleier VOR der Szene für Tiefe — letzte Atmosphäre-Ebene, aber
        // weiter HINTER dem Content (Lesbarkeit bleibt unangetastet).
        if (rainVeil != null)
          RepaintBoundary(
            child: RainVeilLayer(spec: rainVeil, intensity: weatherStrength),
          ),

        // ═══════════ CONTENT (nie überlagert) ═══════════
        child,

        // ═══════════ ULTRA-SUBTLE TOP-LAYER (Filmlook) ═══════════

        // 10. Vignette nur Eck-Falloff, KEIN zentraler Tint
        RepaintBoundary(
          child: VignetteOverlay(
            intensity: spec.vignetteIntensity * intensity,
          ),
        ),

        // 11. Chromatic-Aberration (nur Edge-Pixel)
        RepaintBoundary(
          child: ChromaticAberration(
            amount: spec.chromaticAberration * intensity,
          ),
        ),

        // 12. Film-Grain — teurster animierter Effekt. Bei intensity < 0.6
        // komplett ueberspringen (= reduced/minimal Mode).
        if (intensity >= 0.6)
          RepaintBoundary(
            child: FilmGrainOverlay(opacity: spec.grainOpacity * intensity),
          ),
      ],
      ),
      ),
    );
  }

  /// Wetter-Atmosphäre OHNE das übrige Kino (Sonne/Mond/Grain/God-Rays). Wird
  /// gerendert, wenn der Cinema-Master aus ist (Mode=Aus / A11y / Lite), der
  /// Live-Wetter-Schalter aber an ist. So bleibt der Wetter-Hintergrund „immer
  /// live", unabhängig vom Effekt-Profil. Tint/Mood (reine Farb-Ebenen) laufen
  /// immer; animierte Ebenen (Wolken/Nebel/Partikel/Blitz/Schleier) nur, wenn
  /// [motion] erlaubt ist (kein Lite, keine A11y-Bewegungsreduktion). Gibt es
  /// nichts zu zeigen (klarer Himmel / Daten fehlen), kommt der reine Content.
  Widget _weatherOnlyOverlay({
    required Widget child,
    required Color? weatherTint,
    required Color? thunderMood,
    required Color? cloudColor,
    required int cloudDensity,
    required CinemaWeather weather,
    required CinemaParticleSpec? weatherParticles,
    required RainVeilSpec? rainVeil,
    required double strength,
    required bool motion,
  }) {
    final layers = <Widget>[
      // Statischer Wetter-Tint (Regen/Nebel/Schnee/Gewitter).
      if (weatherTint != null)
        Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: weatherTint)),
        ),
      // Gewitter-Stimmung (dunkler Top-Down-Tint).
      if (thunderMood != null)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [thunderMood, Colors.transparent],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),
        ),
      // Driftende Wolken (nur mit Bewegung).
      if (motion && cloudColor != null)
        RepaintBoundary(
          child: CloudDriftLayer(
            color: cloudColor,
            intensity: strength,
            count: cloudDensity,
          ),
        ),
      // Nebel-Drift.
      if (motion && weather == CinemaWeather.fog && weatherTint != null)
        RepaintBoundary(
          child: FogDriftLayer(color: weatherTint, intensity: strength),
        ),
      // Regen-/Schnee-Partikel.
      if (motion && weatherParticles != null)
        RepaintBoundary(
          child: CinemaParticleLayer(spec: weatherParticles, intensity: strength),
        ),
      // Gewitter-Blitz.
      if (motion && weather == CinemaWeather.thunder)
        RepaintBoundary(child: LightningFlash(intensity: strength)),
      // Vordergrund-Regenschleier.
      if (motion && rainVeil != null)
        RepaintBoundary(
          child: RainVeilLayer(spec: rainVeil, intensity: strength),
        ),
    ];

    if (layers.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('cinema_overlay_off'),
        child: child,
      );
    }
    return KeyedSubtree(
      key: const ValueKey('cinema_overlay_weather_only'),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ...layers,
            child,
          ],
        ),
      ),
    );
  }
}

/// Drift-Mesh wie in v2, aber leicht ruhiger (45s statt 60s, kleinere Drift).
class _MeshBackground extends StatefulWidget {
  const _MeshBackground({required this.spec, super.key});
  final CinemaPhaseSpec spec;

  @override
  State<_MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<_MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, __) {
        final t = _drift.value;
        final cx = -0.2 + (t - 0.5) * 0.25;
        final cy = -0.4 + (t - 0.5) * 0.20;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(cx, cy),
                  radius: 1.5,
                  colors: widget.spec.bgStops,
                  stops: widget.spec.bgStopPositions,
                ),
              ),
              child: const SizedBox.expand(),
            ),
            for (var i = 0; i < widget.spec.meshHotspots.length; i++)
              IgnorePointer(
                child: _Hotspot(
                  hotspot: widget.spec.meshHotspots[i],
                  driftPhase: i.isEven ? t : 1 - t,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({required this.hotspot, required this.driftPhase});
  final MeshHotspot hotspot;
  final double driftPhase;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final diameter = media.shortestSide * hotspot.radius * 2;
    final shift = (driftPhase - 0.5) * 0.15;
    final align = Alignment(
      hotspot.alignment.x + shift,
      hotspot.alignment.y - shift,
    );
    return Align(
      alignment: align,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                hotspot.color.withValues(alpha: hotspot.opacity),
                hotspot.color.withValues(alpha: hotspot.opacity * 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
