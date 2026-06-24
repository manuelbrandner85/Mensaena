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

    // CRASH-FIX: Off-Mode (phase null oder intensity ~0) und On-Mode
    // ergeben strukturell SEHR unterschiedliche Widget-Trees (SizedBox vs
    // RepaintBoundary > Stack > 9+ AnimationControllers). Beim Toggle
    // kann die Disposal-Reihenfolge der alten Controllers mit dem Mount
    // der neuen kollidieren → Crash bei Navigation. KeyedSubtree
    // erzwingt sauberen Unmount der einen Variante vor Mount der anderen.
    // Auf Lite weiterhin abschalten — AUSSER Video/Parallax ist aktiv (die
    // sind leicht und vom User explizit gewünscht). reduceMotion/cinema-off
    // (profile.isOff) sowie phase==null bleiben hart aus.
    if (phase == null || profile.isOff || (liteMode && !parallaxOn)) {
      return KeyedSubtree(
        key: const ValueKey('cinema_overlay_off'),
        child: child,
      );
    }

    final spec = CinemaTheme.specFor(phase);
    // Feinregler (0–100 %) skaliert die atmosphärische Stärke stufenlos.
    final strength = ref.watch(cinemaEffectStrengthProvider) / 100.0;
    final intensity =
        (isLight ? (baseIntensity * 0.3) : baseIntensity) * strength;
    // ECHTE aktuelle Wetterlage am Standort (eine Quelle: Now-Provider).
    // Tint/Kondition/Partikel werden hieraus abgeleitet — keine Stunden-/
    // Zeitzonen-Fehlzuordnung mehr.
    final weatherNow = ref.watch(cinemaWeatherNowProvider).value;
    final weatherBase = weatherTintOf(weatherNow);
    // WETTER-ADAPTIVE STIMMUNG = eigene, leichte Ebene. Sie ist sichtbar,
    // sobald der Schalter an ist (Default an) — UNABHÄNGIG vom Effekt-Profil
    // und Light-Mode. Vorher hing sie an intensity>=0.6, war also im
    // Light-Mode (×0.3) und auf reduced/minimal NIE zu sehen → "nicht immer
    // live". Eigene Stärke mit sichtbarem Floor, vom 0–100%-Regler skaliert.
    final weatherAdaptiveOn = ref.watch(cinemaWeatherAdaptiveProvider);
    final weatherStrength = weatherAdaptiveOn
        ? (((isLight ? 0.60 : 0.82) * strength).clamp(0.45, 1.0)).toDouble()
        : 0.0;
    // Partikel (Regen/Schnee) haben einen eigenen AnimationController → auf
    // Lite-Geräten weiter AUS (ARM32-Crash-Historie). Tint + Kondition (Nebel/
    // Blitz-Tint) sind reine Farb-/Maluebenen und laufen auch dort.
    final weatherParticlesEnabled = weatherAdaptiveOn && !liteMode;
    // Echte driftende Wolken bei wolkig/Regen/Schnee/Gewitter (eigener
    // Controller → auf Lite aus). null = klar/Nebel (keine Wolken).
    final cloudColor =
        weatherParticlesEnabled ? cloudColorOf(weatherNow) : null;
    final cloudDensity = cloudDensityFor(weatherNow);
    // Vordergrund-Regenschleier (Regen/Gewitter, eigener Controller → Lite aus).
    final rainVeil = weatherParticlesEnabled ? rainVeilFor(weatherNow) : null;
    // Gewitter-Stimmung: schwerer, dunkler Top-Tint. Reine Farb-Ebene → läuft
    // auch auf Lite (nur am Wetter-Schalter, nicht an den Partikeln).
    final thunderBase = weatherAdaptiveOn ? thunderMoodColor(weatherNow) : null;
    final thunderMood = thunderBase == null
        ? null
        : Color.lerp(Colors.transparent, thunderBase, weatherStrength);
    final weatherTint = (weatherBase == null || !weatherAdaptiveOn)
        ? null
        : Color.lerp(Colors.transparent, weatherBase, weatherStrength);
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
    // Wetter-Kondition/Partikel hängen am Wetter-Schalter, NICHT an heavyOn.
    final weather =
        weatherAdaptiveOn ? weatherConditionOf(weatherNow) : CinemaWeather.clear;
    final weatherParticles =
        weatherParticlesEnabled ? weatherParticleSpec(weatherNow) : null;
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
        if (weather == CinemaWeather.thunder && weatherParticlesEnabled)
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
