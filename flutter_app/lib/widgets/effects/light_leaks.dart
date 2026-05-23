import 'package:flutter/material.dart';

import '../../config/theme/cinema_theme.dart';

/// SKILL: mensaena-design
/// Cinema-Light-Leaks — weiche warme Lichtflecken am Bildschirmrand.
/// Sonnenstand-Anlehnung: Bei Dämmerung Sonne am Horizont, Reflexe in
/// Kamera-Linse → warmes Glow am Rand.
class LightLeaksOverlay extends StatelessWidget {
  const LightLeaksOverlay({required this.spots, super.key});

  final List<LightLeakSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          for (final s in spots)
            Align(
              alignment: s.alignment,
              child: _LightSpot(spot: s),
            ),
        ],
      ),
    );
  }
}

class _LightSpot extends StatelessWidget {
  const _LightSpot({required this.spot});
  final LightLeakSpot spot;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final diameter = (media.shortestSide * spot.radius * 2).clamp(120.0, 700.0);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              spot.color.withValues(alpha: spot.opacity),
              spot.color.withValues(alpha: spot.opacity * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}
