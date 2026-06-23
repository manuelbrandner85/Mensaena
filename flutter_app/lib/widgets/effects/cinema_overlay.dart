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
import 'cinematic_video_backdrop.dart';
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
    // Video + Parallax sind leicht (GPU-Video / günstiger Transform) und sollen
    // auf JEDEM Gerät laufen, sobald ihr Schalter an ist — daher unabhängig
    // von isFull/Lite. Die teuren Atmosphären-Ebenen bleiben über das
    // intensity>=0.6-Gate trotzdem aus.
    final videoOn = ref.watch(cinemaVideoBackdropProvider);
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
    if (phase == null ||
        profile.isOff ||
        (liteMode && !videoOn && !parallaxOn)) {
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
    // Wetter-adaptiver Tint (Regen/Nebel/Schnee/Gewitter) — leichtgewichtig,
    // mit der Intensität skaliert.
    final weatherBase = ref.watch(cinemaWeatherAdaptiveProvider)
        ? ref.watch(cinemaWeatherTintProvider).value
        : null;
    // Intensitäts-Skalierung via lerp von transparent → Tint (kein Color.a,
    // versionsunabhängig).
    final weatherTint = weatherBase == null
        ? null
        : Color.lerp(Colors.transparent, weatherBase, intensity);
    // Saisonaler Tint (datumsbasiert, keine Netzwerklast).
    final seasonalBase = ref.watch(cinemaSeasonalProvider)
        ? seasonalTintForMonth(DateTime.now().month)
        : null;
    final seasonalTint = seasonalBase == null
        ? null
        : Color.lerp(Colors.transparent, seasonalBase, intensity);
    // Video-Hintergrund sobald der Schalter an ist (läuft auf jedem Gerät,
    // GPU-dekodiert). alwaysPlay umgeht die isFull-Sperre im Widget.
    final phaseVideo = videoOn ? _videoAssetsForPhase(phase) : null;

    return KeyedSubtree(
      key: const ValueKey('cinema_overlay_on'),
      child: RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
        // ═══════════ BACKGROUND-STACK (alle hinter Content) ═══════════

        // 1. Hintergrund: bewegtes Video je Tageszeit (nur full + Schalter an)
        // ODER der animierte Mesh-Gradient (Standard / bei Crash-Schutz).
        // In CinemaParallax gewrappt → subtile Neige-Tiefe (nur full + an).
        CinemaParallax(
          child: phaseVideo != null
              ? RepaintBoundary(
                  child: CinematicVideoBackdrop(
                    key: ValueKey('video_${phase.name}'),
                    videoAsset: phaseVideo.video,
                    stillAsset: phaseVideo.still,
                    alwaysPlay: true,
                    topScrim: 0.25,
                    bottomScrim: 0.7,
                  ),
                )
              : RepaintBoundary(
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

        // 2. Atmospheric Haze (Tiefen-Eindruck oben→unten)
        RepaintBoundary(
          child: AtmosphericHaze(
            topColor: spec.bgStops.first,
            bottomColor: spec.bgStops.last,
            intensity: intensity,
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
          ),
        ),

        // 5. God-Rays vom Sky-Body — nur bei full intensity.
        if (spec.hasGodRays && intensity >= 0.6)
          RepaintBoundary(
            child: GodRays(
              source: spec.skyBody.alignment,
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

/// Phase → (Loop-Video, Standbild-Fallback) für den Video-Hintergrund.
({String video, String still}) _videoAssetsForPhase(CinemaPhase phase) {
  switch (phase) {
    case CinemaPhase.night:
      return (
        video: 'assets/videos/splash_cosmos.mp4',
        still: 'assets/images/splash_cosmos.webp',
      );
    case CinemaPhase.dusk:
    case CinemaPhase.evening:
      return (
        video: 'assets/videos/splash_dusk.mp4',
        still: 'assets/images/splash_dusk.webp',
      );
    case CinemaPhase.dawn:
    case CinemaPhase.morning:
    case CinemaPhase.day:
      return (
        video: 'assets/videos/dorf_intro.mp4',
        still: 'assets/images/dorf_morning.webp',
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
