import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 3 konzentrische Amber-Wellen, die sich nacheinander ausdehnen und
/// ausfaden. Used: Karten-User-Standort, "Live"-Indikatoren, Splash.
class NeighborhoodPulse extends StatefulWidget {
  final double maxRadius;
  final Color color;
  final Duration cycle;

  const NeighborhoodPulse({
    super.key,
    this.maxRadius = 200,
    this.color = MnColors.amber,
    this.cycle = const Duration(seconds: 6),
  });

  @override
  State<NeighborhoodPulse> createState() => _NeighborhoodPulseState();
}

class _NeighborhoodPulseState extends State<NeighborhoodPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycle)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _PulsePainter(
            progress: _ctrl.value,
            maxRadius: widget.maxRadius,
            color: widget.color,
          ),
          size: Size(widget.maxRadius * 2, widget.maxRadius * 2),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final double maxRadius;
  final Color color;

  _PulsePainter({
    required this.progress,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      // 3 Wellen, jeweils um 1/3 versetzt.
      final phase = (progress + i / 3) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.20;
      if (opacity <= 0.005) continue;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.progress != progress;
}
