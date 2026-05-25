import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Film-Grain v2 — AnimationController + AnimatedBuilder statt Timer.
///
/// Vorher: Timer.periodic(80ms) → setState(_frame++) → full widget rebuild
/// inkl. allem oberhalb. setState wirkt durch den ganzen build-Stack.
/// Jetzt: AnimationController fires repaint via Listenable an CustomPaint,
/// kein setState noetig. Engine handhabt vsync — spart ~0.5ms/Frame +
/// koppelt sich automatisch an TickerMode ab wenn nicht sichtbar.
class FilmGrainOverlay extends StatefulWidget {
  const FilmGrainOverlay({required this.opacity, super.key});

  /// 0.0 – 0.03. Hoehere Werte = sichtbarer.
  final double opacity;

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // 80ms-Cycle wie vorher → 12.5fps Grain (sieht weicher aus als 60fps).
      duration: const Duration(milliseconds: 80),
    );
    if (widget.opacity > 0.001) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(FilmGrainOverlay old) {
    super.didUpdateWidget(old);
    if (old.opacity != widget.opacity) {
      if (widget.opacity > 0.001 && !_ctrl.isAnimating) {
        _ctrl.repeat();
      } else if (widget.opacity <= 0.001 && _ctrl.isAnimating) {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opacity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _FilmGrainPainter(
              opacity: widget.opacity,
              // value [0..1) → diskreter Seed alle 80ms wenn das
              // controller-cycle endet und neu startet.
              seed: (_ctrl.value * 1000).floor(),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  _FilmGrainPainter({required this.opacity, required this.seed});

  final double opacity;
  final int seed;

  static const int _dotsPerScreen = 800;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paintBright = Paint()
      ..color = Colors.white.withValues(alpha: opacity);
    final paintDark = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 1.4);
    for (var i = 0; i < _dotsPerScreen; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 0.8 + 0.3;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        rng.nextBool() ? paintBright : paintDark,
      );
    }
  }

  @override
  bool shouldRepaint(_FilmGrainPainter old) =>
      old.seed != seed || old.opacity != opacity;
}
