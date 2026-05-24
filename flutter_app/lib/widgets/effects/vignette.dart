/// SKILL: mensaena-design
/// Cinema-Vignette v3 — nur weiche Eck-Verdunkelung, kein zentraler
/// Falloff. Lesbarkeit-first: zentrale 75 % der Fläche bleiben 100 %
/// transparent. Erst in den letzten 25 % zum Rand wird sanft abgedunkelt.
library;

import 'package:flutter/material.dart';

class VignetteOverlay extends StatelessWidget {
  const VignetteOverlay({required this.intensity, super.key});

  /// 0.0 – 0.5. Höhere Werte = dunklere Ecken.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.25,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: intensity * 0.35),
              Colors.black.withValues(alpha: intensity * 0.85),
            ],
            stops: const [0.0, 0.75, 0.92, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
