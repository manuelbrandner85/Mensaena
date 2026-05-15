import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Gluehwuermchen: 10 Partikel auf Lissajous-Kurven mit Noise-Versatz.
/// Sparsam einsetzen — nur Splash, Auth, Landing-Hero, Footer-CTA.
class FirefliesWidget extends StatefulWidget {
  final int count;
  const FirefliesWidget({super.key, this.count = 10});

  @override
  State<FirefliesWidget> createState() => _FirefliesWidgetState();
}

class _FirefliesWidgetState extends State<FirefliesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_Firefly> _flies;
  final math.Random _rng = math.Random(7);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _flies = List.generate(widget.count, (i) {
      return _Firefly(
        ampX: 0.15 + _rng.nextDouble() * 0.25,
        ampY: 0.10 + _rng.nextDouble() * 0.20,
        freqX: 0.05 + _rng.nextDouble() * 0.10,
        freqY: 0.07 + _rng.nextDouble() * 0.10,
        phase: _rng.nextDouble() * math.pi * 2,
        centerX: 0.15 + _rng.nextDouble() * 0.70,
        centerY: 0.20 + _rng.nextDouble() * 0.60,
        cyclePeriod: 7.0 + _rng.nextDouble() * 5.0,
        cycleOffset: _rng.nextDouble() * 10,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _FirefliesPainter(_flies, _ctrl.value * 60),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Firefly {
  final double ampX, ampY, freqX, freqY, phase, centerX, centerY;
  final double cyclePeriod;
  final double cycleOffset;

  const _Firefly({
    required this.ampX,
    required this.ampY,
    required this.freqX,
    required this.freqY,
    required this.phase,
    required this.centerX,
    required this.centerY,
    required this.cyclePeriod,
    required this.cycleOffset,
  });
}

class _FirefliesPainter extends CustomPainter {
  final List<_Firefly> flies;
  final double t;

  _FirefliesPainter(this.flies, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flies) {
      final x = (f.centerX + f.ampX * math.sin(2 * math.pi * f.freqX * t + f.phase)) * size.width;
      final y = (f.centerY + f.ampY * math.sin(2 * math.pi * f.freqY * t)) * size.height;

      // Opazitaet folgt eigenem langsamen Sinus (Lebenszyklus).
      final cycleT = ((t + f.cycleOffset) % f.cyclePeriod) / f.cyclePeriod;
      final opacity = math.sin(cycleT * math.pi) * 0.65;
      if (opacity <= 0.01) continue;

      final paint = Paint()
        ..color = MnColors.amberSoft.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter old) => old.t != t;
}
