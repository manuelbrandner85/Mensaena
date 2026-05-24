import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/cinema_theme.dart';
import '../../providers/cinema_provider.dart';
import 'film_grain.dart';
import 'light_leaks.dart';
import 'vignette.dart';

/// SKILL: mensaena-design
/// CinemaOverlay — Wrapt jeden Screen mit 5 Layers:
///
/// 1. Background-Mesh-Gradient (HINTER dem Content)
/// 2. Screen-Content (eigentliches UI)
/// 3. Tint-Layer (overlay, sehr leichter Phase-Tint)
/// 4. Light-Leaks (bei Dämmerung)
/// 5. Vignette
/// 6. Film-Grain (oben, animiert)
///
/// Wechselt smooth zwischen Phasen mit AnimatedSwitcher (30s).
class CinemaOverlay extends ConsumerWidget {
  const CinemaOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    if (phase == null) {
      // CinemaMode.off — pures Cinema-Dark ohne Effekte
      return child;
    }
    final spec = CinemaTheme.specFor(phase);
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Hintergrund-Mesh-Gradient (cross-fade zwischen Phasen)
        AnimatedSwitcher(
          duration: const Duration(seconds: 8),
          child: KeyedSubtree(
            key: ValueKey('bg_${phase.name}'),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.2, -0.4),
                  radius: 1.4,
                  colors: spec.bgStops,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // 2. Eigentlicher Content (transparent damit Hintergrund durchscheint)
        child,

        // 3. Color-Grade-Tint (overlay)
        IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(seconds: 8),
            color: spec.tintColor.withValues(alpha: spec.tintOpacity),
          ),
        ),

        // 4. Light-Leaks
        AnimatedSwitcher(
          duration: const Duration(seconds: 8),
          child: KeyedSubtree(
            key: ValueKey('leaks_${phase.name}'),
            child: LightLeaksOverlay(spots: spec.leakSpots),
          ),
        ),

        // 5. Vignette
        AnimatedSwitcher(
          duration: const Duration(seconds: 8),
          child: KeyedSubtree(
            key: ValueKey('vig_${phase.name}'),
            child: VignetteOverlay(intensity: spec.vignetteIntensity),
          ),
        ),

        // 6. Film-Grain (animiert oben drueber)
        FilmGrainOverlay(opacity: spec.grainOpacity),
      ],
    );
  }
}
