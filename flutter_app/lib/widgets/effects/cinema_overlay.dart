/// SKILL: mensaena-design
/// CinemaOverlay v2 — Hyperrealistic Layer-Stack mit 9 Layers + Drift.
///
/// Layer (bottom → top):
///   1. Base-Mesh-Gradient (5-stop, RadialGradient, langsame Drift 60s)
///   2. Mesh-Hotspots (2 sekundäre Radial-Blobs, BlendMode für echte Mesh)
///   3. Sky-Body (Sonne/Mond mit Bloom-Glow)
///   4. Lens-Flare (nur Dawn/Dusk)
///   5. Screen-Content (eigentliches UI)
///   6. Color-Grade-Tint (overlay)
///   7. Light-Leaks (pulsierend wo aktiviert)
///   8. Vignette
///   9. Film-Grain (animiert)
///   10. Chromatic-Aberration (Edge-Shift, nur Nacht/Dusk)
///
/// Alle Layer respektieren CinemaIntensity-Multiplier (full/reduced/minimal)
/// und sind in RepaintBoundary verpackt — kein Repaint des Subtrees.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/cinema_theme.dart';
import '../../providers/cinema_provider.dart';
import 'chromatic_aberration.dart';
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
    if (phase == null) {
      return child;
    }
    final spec = CinemaTheme.specFor(phase);
    final intensity = ref.watch(cinemaIntensityProvider).multiplier;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1+2. Drifting Mesh-Gradient mit Hotspots
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(seconds: 8),
            child: _MeshBackground(
              key: ValueKey('mesh_${phase.name}'),
              spec: spec,
            ),
          ),
        ),

        // 3. Sky-Body (Sonne/Mond)
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(seconds: 8),
            child: SkyBody(
              key: ValueKey('sky_${phase.name}'),
              spec: spec.skyBody,
              intensity: intensity,
            ),
          ),
        ),

        // 4. Lens-Flare (optional)
        if (spec.lensFlare != null)
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(seconds: 8),
              child: LensFlare(
                key: ValueKey('flare_${phase.name}'),
                spec: spec.lensFlare!,
                intensity: intensity,
              ),
            ),
          ),

        // 5. Screen-Content
        child,

        // 6. Color-Grade-Tint
        IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(seconds: 8),
            color: spec.tintColor
                .withValues(alpha: spec.tintOpacity * intensity),
          ),
        ),

        // 7. Light-Leaks
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(seconds: 8),
            child: LightLeaksOverlay(
              key: ValueKey('leaks_${phase.name}'),
              spots: spec.leakSpots,
              intensity: intensity,
            ),
          ),
        ),

        // 8. Vignette
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(seconds: 8),
            child: VignetteOverlay(
              key: ValueKey('vig_${phase.name}'),
              intensity: spec.vignetteIntensity * intensity,
            ),
          ),
        ),

        // 9. Film-Grain
        RepaintBoundary(
          child: FilmGrainOverlay(opacity: spec.grainOpacity * intensity),
        ),

        // 10. Chromatic-Aberration
        RepaintBoundary(
          child: ChromaticAberration(
              amount: spec.chromaticAberration * intensity),
        ),
      ],
    );
  }
}

/// Driftende Mesh-Gradient-Kombination aus Haupt-Gradient + Hotspots.
/// Drift bewegt das Gradient-Zentrum langsam in einer 60-Sekunden-Schleife.
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
      duration: const Duration(seconds: 60),
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
        // Drift ±0.15 in beide Achsen
        final cx = -0.2 + (t - 0.5) * 0.30;
        final cy = -0.4 + (t - 0.5) * 0.25;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Haupt-Gradient
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
            // Hotspots (driften gegenläufig)
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
    // Drift ±0.1 vom Anker.
    final shift = (driftPhase - 0.5) * 0.2;
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
