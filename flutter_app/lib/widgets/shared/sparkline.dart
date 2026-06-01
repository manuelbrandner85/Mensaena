/// SKILL: mensaena-design
/// Sparkline — minimalistischer Verlaufs-Graph (#V4). Pure CustomPaint,
/// kein externes Chart-Package. Zeichnet eine geglättete Linie + dezenten
/// Flächen-Verlauf darunter. Lite-Mode-bewusst über den Aufrufer.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.color = AppColors.bronze,
    this.height = 40,
    this.fill = true,
    super.key,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: color, fill: fill),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.fill,
  });
  final List<double> values;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final n = values.length;
    final dx = size.width / (n - 1);

    double yFor(double v) {
      // 4px Padding oben/unten damit Spitzen nicht abgeschnitten werden.
      final t = (v - minV) / range;
      return 4 + (1 - t) * (size.height - 8);
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = dx * i;
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Endpunkt markieren.
    final last = Offset(size.width, yFor(values.last));
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}
