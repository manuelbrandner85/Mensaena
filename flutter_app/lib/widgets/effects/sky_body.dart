/// SKILL: mensaena-design
/// Sky-Body — sichtbare Sonne oder Mond mit Bloom-Glow.
/// Subtile Atmung-Animation (5s loop) erzeugt Lebendigkeit.
library;

import 'package:flutter/material.dart';

import '../../config/theme/cinema_theme.dart';

class SkyBody extends StatefulWidget {
  const SkyBody({required this.spec, required this.intensity, super.key});

  final SkyBodySpec spec;
  final double intensity; // 0.0 – 1.0

  @override
  State<SkyBody> createState() => _SkyBodyState();
}

class _SkyBodyState extends State<SkyBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: widget.spec.alignment,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final breath = 0.95 + _ctrl.value * 0.10;
            final d = widget.spec.diameter * breath;
            final glowD = d * 3.2;
            return SizedBox(
              width: glowD,
              height: glowD,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer-Glow (BlendMode plus für additives Leuchten)
                  _glowRing(glowD, widget.spec.glow,
                      widget.intensity * 0.55, 0.0, 1.0),
                  _glowRing(glowD * 0.6, widget.spec.glow,
                      widget.intensity * 0.75, 0.0, 1.0),
                  // Core
                  Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.spec.core
                              .withValues(alpha: widget.intensity * 0.95),
                          widget.spec.core
                              .withValues(alpha: widget.intensity * 0.75),
                          widget.spec.glow
                              .withValues(alpha: widget.intensity * 0.40),
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: widget.spec.isMoon
                        ? _MoonCraters(intensity: widget.intensity)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _glowRing(double size, Color color, double alpha,
      double innerStop, double outerStop) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.4),
            Colors.transparent,
          ],
          stops: [innerStop, 0.5, outerStop],
        ),
      ),
    );
  }
}

class _MoonCraters extends StatelessWidget {
  const _MoonCraters({required this.intensity});
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MoonCraterPainter(intensity: intensity),
    );
  }
}

class _MoonCraterPainter extends CustomPainter {
  _MoonCraterPainter({required this.intensity});
  final double intensity;

  // Feste Krater-Positionen für Wiedererkennbarkeit.
  static const List<List<double>> _craters = [
    [0.30, 0.35, 0.10],
    [0.65, 0.55, 0.07],
    [0.45, 0.70, 0.05],
    [0.72, 0.30, 0.04],
    [0.25, 0.65, 0.06],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * intensity);
    for (final c in _craters) {
      canvas.drawCircle(
        Offset(size.width * c[0], size.height * c[1]),
        size.shortestSide * c[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MoonCraterPainter old) =>
      old.intensity != intensity;
}
