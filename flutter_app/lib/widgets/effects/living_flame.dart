/// SKILL: mensaena-design (Premium-Motion / Paket D Stolz-Momente)
/// LivingFlame — lebendige Mini-Flamme für Streak-Widgets.
///
/// EffectsGate-integriert:
///   full          → 2-Layer-CustomPainter-Flamme mit sanftem Flackern
///                   (1 AnimationController, RepaintBoundary, TickerMode
///                   pausiert offscreen automatisch)
///   reduced/none  → statisches Flame-Icon (exakt der bisherige Look)
///
/// Emil-Prinzip: Die Flamme ist Dekoration eines seltenen Stolz-Moments
/// (Streak), kein UI-Feedback — darum darf sie dauerhaft leben, aber nur
/// auf `full` und nur als billige 2-Pfad-Zeichnung pro Frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/effects_gate_provider.dart';

class LivingFlame extends ConsumerStatefulWidget {
  const LivingFlame({
    required this.color,
    this.size = 22,
    super.key,
  });

  final Color color;
  final double size;

  @override
  ConsumerState<LivingFlame> createState() => _LivingFlameState();
}

class _LivingFlameState extends ConsumerState<LivingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    // Langsamer Zyklus — Flackern entsteht aus überlagerten Sinus-Phasen,
    // nicht aus der Frequenz. Schnelles Flackern wirkt nervös statt warm.
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(effectsProfileProvider);
    if (!profile.isFull) {
      // reduced/none: identisch zum bisherigen statischen Icon.
      if (_ctrl.isAnimating) _ctrl.stop();
      return Icon(LucideIcons.flame, size: widget.size, color: widget.color);
    }
    if (!_ctrl.isAnimating) _ctrl.repeat();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FlamePainter(color: widget.color, t: _ctrl.value),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t * 2 * math.pi;
    // Zwei überlagerte Sinus-Wellen → organisches, nicht-periodisch
    // wirkendes Flackern (klassischer Fake-Noise, 0 Allokationen).
    final sway = (math.sin(phase) * 0.6 + math.sin(phase * 2.3 + 1.7) * 0.4) *
        w * 0.05;
    final lick =
        (math.sin(phase * 3.1 + 0.5) * 0.5 + 0.5) * h * 0.08;

    canvas.drawPath(
      _flamePath(w, h, sway, lick),
      Paint()..color = color.withValues(alpha: 0.95),
    );
    // Innerer Kern: heller, kleiner, leicht nach oben versetzt,
    // gegenläufige Sway-Phase → Tiefe.
    canvas.save();
    canvas.translate(w * 0.5 - sway * 0.5, h * 0.32);
    canvas.scale(0.55);
    canvas.translate(-w * 0.5, -h * 0.18);
    canvas.drawPath(
      _flamePath(w, h, -sway * 0.6, lick * 0.7),
      Paint()
        ..color = Color.lerp(color, Colors.white, 0.55)!
            .withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  /// Tropfenform: Spitze oben (mit Sway), Bauch unten. Rein aus zwei
  /// Bezier-Segmenten — billig genug für 60 fps auf Mittelklasse-Geräten.
  Path _flamePath(double w, double h, double sway, double lick) {
    final tipX = w * 0.5 + sway;
    final tipY = h * 0.06 + lick;
    final baseY = h * 0.94;
    return Path()
      ..moveTo(tipX, tipY)
      ..cubicTo(
        w * 0.86 + sway * 0.4, h * 0.34,
        w * 0.88, h * 0.72,
        w * 0.5, baseY,
      )
      ..cubicTo(
        w * 0.12, h * 0.72,
        w * 0.14 + sway * 0.4, h * 0.34,
        tipX, tipY,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t || old.color != color;
}
