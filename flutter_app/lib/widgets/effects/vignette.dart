/// SKILL: mensaena-design
/// Cinema-Vignette — dramatischer dunkler Rand-Fall via 3-Stop-RadialGradient.
/// Intensität phasenabhängig (Nacht ~0.60, Tag ~0.20).
library;

import 'package:flutter/material.dart';

class VignetteOverlay extends StatelessWidget {
  const VignetteOverlay({required this.intensity, super.key});

  /// 0.0 – 0.7. Höhere Werte = dunklerer Rand.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: intensity * 0.30),
              Colors.black.withValues(alpha: intensity * 0.65),
              Colors.black.withValues(alpha: intensity),
            ],
            stops: const [0.35, 0.65, 0.85, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
