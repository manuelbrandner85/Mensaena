/// SKILL: mensaena-design
/// Chromatic-Aberration — subtiler R/B-Pixel-Shift am Bildschirmrand
/// für High-End-Lens-Look. Nur in Nacht + Dusk-Phasen aktiv.
library;

import 'package:flutter/material.dart';

class ChromaticAberration extends StatelessWidget {
  const ChromaticAberration({required this.amount, super.key});

  /// Pixel-Shift (0.0 – 4.0). 0 = aus.
  final double amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0.05) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _AberrationPainter(amount: amount),
        size: Size.infinite,
      ),
    );
  }
}

class _AberrationPainter extends CustomPainter {
  _AberrationPainter({required this.amount});
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final maxShift = amount;
    // Rot-Edge links
    final red = Paint()
      ..color = const Color(0x33FF1A4A).withValues(alpha: 0.10 * amount);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, maxShift * 1.5, size.height),
      red,
    );
    // Blau-Edge rechts
    final blue = Paint()
      ..color = const Color(0x331A4AFF).withValues(alpha: 0.10 * amount);
    canvas.drawRect(
      Rect.fromLTWH(size.width - maxShift * 1.5, 0, maxShift * 1.5, size.height),
      blue,
    );
    // Subtile Eck-Verzerrung (R/B-Diagonale)
    final corner = Paint()
      ..color = const Color(0x33FF00FF).withValues(alpha: 0.06 * amount)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 60, corner);
    canvas.drawCircle(Offset(size.width, size.height), 60, corner);
  }

  @override
  bool shouldRepaint(_AberrationPainter old) => old.amount != amount;
}
