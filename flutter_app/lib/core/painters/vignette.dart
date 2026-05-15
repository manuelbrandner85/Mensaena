import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Asymmetrische Vignette. Oben staerker (Nachthimmel), unten schwaecher
/// (warmes Licht von unten). Simuliert anamorphes Kameraobjektiv.
class VignetteWidget extends StatelessWidget {
  const VignetteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _VignettePainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Oben: starker Schwarz-Verlauf von 60% auf 0%.
    final top = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height * 0.45),
        [const Color(0x99000000), const Color(0x00000000)],
      );
    canvas.drawRect(rect, top);

    // Unten: schwacher Schwarz-Verlauf von 0% auf 25%.
    final bottom = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, size.height * 0.55),
        Offset(size.width / 2, size.height),
        [const Color(0x00000000), const Color(0x40000000)],
      );
    canvas.drawRect(rect, bottom);

    // Seiten: mittlerer Schwarz-Schatten von Raendern her.
    final sides = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.shortestSide * 0.75,
        [const Color(0x00000000), const Color(0x66000000)],
        const [0.55, 1.0],
      );
    canvas.drawRect(rect, sides);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) => false;
}
