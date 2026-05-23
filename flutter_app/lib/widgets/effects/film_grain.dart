import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Film-Grain — procedurales animiertes Rauschen ueber dem gesamten Screen.
/// Tick alle 80ms — verschiebt das Noise-Pattern leicht.
class FilmGrainOverlay extends StatefulWidget {
  const FilmGrainOverlay({required this.opacity, super.key});

  /// 0.0 – 0.03. Hoehere Werte = sichtbarer.
  final double opacity;

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (widget.opacity > 0.001) {
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (mounted) setState(() => _frame++);
      });
    }
  }

  @override
  void didUpdateWidget(FilmGrainOverlay old) {
    super.didUpdateWidget(old);
    if (old.opacity != widget.opacity) {
      _timer?.cancel();
      if (widget.opacity > 0.001) {
        _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
          if (mounted) setState(() => _frame++);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opacity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _FilmGrainPainter(
          opacity: widget.opacity,
          seed: _frame,
        ),
        size: Size.infinite,
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
