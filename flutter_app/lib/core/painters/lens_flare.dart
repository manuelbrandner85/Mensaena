import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Anamorphic Lens-Flare: dezenter horizontaler Amber-Streak.
/// Wird einmal beim Auftauchen abgespielt — fadeIn 0.6s, hold 0.8s,
/// fadeOut 0.6s. Sparsam einsetzen (Splash-Logo, Hero-Headline,
/// Sektionswechsel).
class LensFlare extends StatefulWidget {
  final double widthFraction;
  final double yPosition;
  final Duration totalDuration;

  const LensFlare({
    super.key,
    this.widthFraction = 0.5,
    this.yPosition = 0.5,
    this.totalDuration = const Duration(milliseconds: 2000),
  });

  @override
  State<LensFlare> createState() => _LensFlareState();
}

class _LensFlareState extends State<LensFlare>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.totalDuration)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _opacity(double t) {
    // 0.0–0.3: fadeIn, 0.3–0.7: hold, 0.7–1.0: fadeOut.
    if (t < 0.3) return t / 0.3;
    if (t < 0.7) return 1.0;
    return (1.0 - t) / 0.3;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final op = _opacity(_ctrl.value);
          if (op <= 0.01) return const SizedBox.shrink();
          return CustomPaint(
            painter: _LensFlarePainter(
              widthFraction: widget.widthFraction,
              yPosition: widget.yPosition,
              opacity: op,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _LensFlarePainter extends CustomPainter {
  final double widthFraction;
  final double yPosition;
  final double opacity;

  _LensFlarePainter({
    required this.widthFraction,
    required this.yPosition,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * widthFraction;
    final cx = size.width / 2;
    final cy = size.height * yPosition;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: 2);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        rect.centerLeft,
        rect.centerRight,
        [
          MnColors.amber.withValues(alpha: 0.0),
          MnColors.amberSoft.withValues(alpha: 0.08 * opacity),
          MnColors.amber.withValues(alpha: 0.0),
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _LensFlarePainter old) => old.opacity != opacity;
}
