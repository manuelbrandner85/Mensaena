import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Cinema-Vignette — subtile dunkle Raender via RadialGradient.
/// Intensitaet phasenabhaengig (Nacht ~0.4, Tag ~0.05).
class VignetteOverlay extends StatelessWidget {
  const VignetteOverlay({required this.intensity, super.key});

  /// 0.0 (keine Vignette) bis 0.5 (sehr dunkler Rand).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: intensity * 0.5),
              Colors.black.withValues(alpha: intensity),
            ],
            stops: const [0.4, 0.8, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
