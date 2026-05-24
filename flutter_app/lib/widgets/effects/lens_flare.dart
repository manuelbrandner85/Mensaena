/// SKILL: mensaena-design
/// Lens-Flare — klassischer 4-Strahl-Stern + Highlight-Ring + Linsen-Ghosts.
/// Erscheint nur in Dawn/Dusk-Phasen mit Sonne als Anker.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme/cinema_theme.dart';

class LensFlare extends StatefulWidget {
  const LensFlare({required this.spec, required this.intensity, super.key});

  final LensFlareSpec spec;
  final double intensity; // 0.0 – 1.0

  @override
  State<LensFlare> createState() => _LensFlareState();
}

class _LensFlareState extends State<LensFlare>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
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
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _FlarePainter(
            spec: widget.spec,
            t: _ctrl.value,
            intensity: widget.intensity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _FlarePainter extends CustomPainter {
  _FlarePainter({
    required this.spec,
    required this.t,
    required this.intensity,
  });

  final LensFlareSpec spec;
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (spec.alignment.x + 1) / 2;
    final cy = size.height * (spec.alignment.y + 1) / 2;
    final twinkle = 0.85 + t * 0.30;
    final base = spec.intensity * intensity * twinkle;

    // 4-Strahl-Stern
    final starPaint = Paint()
      ..color = spec.color.withValues(alpha: base * 0.7)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final long = size.shortestSide * 0.45 * base;
    final short = long * 0.35;
    canvas.drawLine(Offset(cx - long, cy), Offset(cx + long, cy), starPaint);
    canvas.drawLine(Offset(cx, cy - short), Offset(cx, cy + short), starPaint);
    // Diagonale Strahlen (45°)
    final diag = long * 0.55;
    final dx = diag * math.cos(math.pi / 4);
    final dy = diag * math.sin(math.pi / 4);
    canvas.drawLine(
        Offset(cx - dx, cy - dy), Offset(cx + dx, cy + dy), starPaint);
    canvas.drawLine(
        Offset(cx - dx, cy + dy), Offset(cx + dx, cy - dy), starPaint);

    // Highlight-Ring um die Sonne
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = spec.color.withValues(alpha: base * 0.35);
    canvas.drawCircle(
        Offset(cx, cy), size.shortestSide * 0.12 * base, ringPaint);

    // Linsen-Ghosts entlang der Diagonale durch Bildmitte (klassisches Lens-Artefakt)
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final ghostPaint = Paint();
    for (var i = 1; i <= 3; i++) {
      final k = i / 3.0;
      final gx = cx + (centerX - cx) * (k * 1.6);
      final gy = cy + (centerY - cy) * (k * 1.6);
      final r = (12 + i * 8) * (0.7 + base * 0.6);
      ghostPaint.shader = RadialGradient(
        colors: [
          spec.color.withValues(alpha: base * 0.18),
          spec.color.withValues(alpha: base * 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(gx, gy), radius: r));
      canvas.drawCircle(Offset(gx, gy), r, ghostPaint);
    }
  }

  @override
  bool shouldRepaint(_FlarePainter old) =>
      old.t != t || old.intensity != intensity || old.spec != spec;
}
