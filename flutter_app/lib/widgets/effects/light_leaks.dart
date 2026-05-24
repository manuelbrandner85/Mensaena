/// SKILL: mensaena-design
/// Cinema-Light-Leaks — weiche warme Lichtflecken am Bildschirmrand.
/// V2: pulsierende Leaks (4s breath) + Intensitäts-Multiplier.
library;

import 'package:flutter/material.dart';

import '../../config/theme/cinema_theme.dart';

class LightLeaksOverlay extends StatelessWidget {
  const LightLeaksOverlay({
    required this.spots,
    this.intensity = 1.0,
    super.key,
  });

  final List<LightLeakSpot> spots;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty || intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          for (final s in spots)
            Align(
              alignment: s.alignment,
              child: s.pulse
                  ? _PulsingSpot(spot: s, intensity: intensity)
                  : _StaticSpot(spot: s, intensity: intensity),
            ),
        ],
      ),
    );
  }
}

class _StaticSpot extends StatelessWidget {
  const _StaticSpot({required this.spot, required this.intensity});
  final LightLeakSpot spot;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return _spotBox(spot, spot.opacity * intensity, context);
  }
}

class _PulsingSpot extends StatefulWidget {
  const _PulsingSpot({required this.spot, required this.intensity});
  final LightLeakSpot spot;
  final double intensity;

  @override
  State<_PulsingSpot> createState() => _PulsingSpotState();
}

class _PulsingSpotState extends State<_PulsingSpot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final breath = 0.75 + _ctrl.value * 0.35;
        return _spotBox(
          widget.spot,
          widget.spot.opacity * widget.intensity * breath,
          context,
        );
      },
    );
  }
}

Widget _spotBox(LightLeakSpot spot, double alpha, BuildContext context) {
  final media = MediaQuery.sizeOf(context);
  final diameter = (media.shortestSide * spot.radius * 2).clamp(120.0, 900.0);
  return SizedBox(
    width: diameter,
    height: diameter,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            spot.color.withValues(alpha: alpha),
            spot.color.withValues(alpha: alpha * 0.55),
            spot.color.withValues(alpha: alpha * 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
      ),
    ),
  );
}
