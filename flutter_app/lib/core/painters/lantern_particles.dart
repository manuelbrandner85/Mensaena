import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Laternenlicht-Partikel. 40 (immersive) / 20 (app) Punkte die sanft
/// glimmen — entfernte Fenster, Strassenlaternen, Lichter durch Dunst.
class LanternParticlesWidget extends StatefulWidget {
  final int count;
  final bool crisisShift;

  const LanternParticlesWidget({
    super.key,
    this.count = 40,
    this.crisisShift = false,
  });

  @override
  State<LanternParticlesWidget> createState() => _LanternParticlesWidgetState();
}

class _LanternParticlesWidgetState extends State<LanternParticlesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_LanternParticle> _particles;
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _particles = _generate(widget.count);
  }

  List<_LanternParticle> _generate(int n) {
    return List.generate(n, (i) {
      // Gewichtet: mehr oben + Raender (entfernte Lichter am Horizont).
      final isUpper = _rng.nextDouble() < 0.6;
      final isEdge = _rng.nextDouble() < 0.4;
      double x = _rng.nextDouble();
      double y = isUpper ? _rng.nextDouble() * 0.5 : _rng.nextDouble();
      if (isEdge) {
        x = _rng.nextBool() ? _rng.nextDouble() * 0.2 : 0.8 + _rng.nextDouble() * 0.2;
      }
      final size = 1.5 + _rng.nextDouble() * 4.5;
      final isMain = i < 5;
      return _LanternParticle(
        relPos: Offset(x, y),
        size: isMain ? 15.0 + _rng.nextDouble() * 5 : size,
        phase: _rng.nextDouble() * math.pi * 2,
        frequency: 0.2 + _rng.nextDouble() * 0.6,
        blur: size > 4 ? 2.0 + _rng.nextDouble() * 2 : 0.0,
        colorSeed: _rng.nextDouble(),
        isMain: isMain,
      );
    });
  }

  @override
  void didUpdateWidget(covariant LanternParticlesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _particles = _generate(widget.count);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _LanternPainter(
            particles: _particles,
            time: _ctrl.value * 30, // 0..30 Sekunden mappen
            crisisShift: widget.crisisShift,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LanternParticle {
  final Offset relPos;
  final double size;
  final double phase;
  final double frequency;
  final double blur;
  final double colorSeed;
  final bool isMain;

  const _LanternParticle({
    required this.relPos,
    required this.size,
    required this.phase,
    required this.frequency,
    required this.blur,
    required this.colorSeed,
    required this.isMain,
  });

  Color color(bool crisisShift) {
    if (crisisShift && colorSeed < 0.3) return MnColors.herzrotWarm;
    if (colorSeed < 0.5) return MnColors.amber;
    if (colorSeed < 0.8) return MnColors.amberWarm;
    if (colorSeed < 0.95) return MnColors.amberSoft;
    return MnColors.trust;
  }
}

class _LanternPainter extends CustomPainter {
  final List<_LanternParticle> particles;
  final double time;
  final bool crisisShift;

  _LanternPainter({
    required this.particles,
    required this.time,
    required this.crisisShift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final pos = Offset(p.relPos.dx * size.width, p.relPos.dy * size.height);
      final pulse = math.sin(time * p.frequency + p.phase);
      // Map -1..1 zu 0.15..0.55.
      final opacity = 0.35 + pulse * 0.20;

      final color = p.color(crisisShift).withValues(alpha: opacity);

      if (p.isMain) {
        // Hauptlaternen: extra Glow-Radial-Gradient.
        final glow = Paint()
          ..shader = ui.Gradient.radial(
            pos,
            30,
            [
              color.withValues(alpha: 0.6),
              color.withValues(alpha: 0.0),
            ],
          );
        canvas.drawCircle(pos, 30, glow);
      }

      final paint = Paint()..color = color;
      if (p.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur);
      }
      canvas.drawCircle(pos, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LanternPainter old) =>
      old.time != time || old.crisisShift != crisisShift;
}
