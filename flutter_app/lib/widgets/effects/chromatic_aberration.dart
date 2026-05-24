/// SKILL: mensaena-design
/// Chromatic-Aberration v3 — extrem subtiler R/B-Pixel-Shift NUR an den
/// äußersten ~30 px Bildschirmrand. Niemals mittig sichtbar.
library;

import 'package:flutter/material.dart';

class ChromaticAberration extends StatelessWidget {
  const ChromaticAberration({required this.amount, super.key});

  /// Stärke 0.0 – 3.0. 0 = aus.
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
    final w = 1.0 + amount * 0.6;
    // Links — Rot-Schimmer
    final red = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFFF1A4A).withValues(alpha: 0.06 * amount),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w * 30, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, w * 30, size.height), red);
    // Rechts — Blau-Schimmer
    final blue = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFF1A4AFF).withValues(alpha: 0.06 * amount),
          Colors.transparent,
        ],
      ).createShader(
          Rect.fromLTWH(size.width - w * 30, 0, w * 30, size.height));
    canvas.drawRect(
        Rect.fromLTWH(size.width - w * 30, 0, w * 30, size.height), blue);
  }

  @override
  bool shouldRepaint(_AberrationPainter old) => old.amount != amount;
}
