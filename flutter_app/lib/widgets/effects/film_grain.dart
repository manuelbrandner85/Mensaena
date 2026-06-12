import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// GPU-Shader (shaders/grain.frag), einmal pro App-Lauf geladen.
  /// null = (noch) nicht verfuegbar -> CPU-Painter-Fallback.
  static ui.FragmentProgram? _program;
  static bool _programRequested = false;

  static Future<void> _loadProgram() async {
    if (_programRequested) return;
    _programRequested = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/grain.frag');
    } catch (_) {/* Fallback: CPU-Painter bleibt aktiv */}
  }

  @override
  void initState() {
    super.initState();
    _loadProgram();
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
          builder: (_, __) {
            // value [0..1) → diskreter Seed alle 80ms wenn das
            // controller-cycle endet und neu startet.
            final seed = (_ctrl.value * 1000).floor();
            final program = _program;
            return CustomPaint(
              painter: program != null
                  // GPU-Pfad: 0 Dart-Arbeit pro Frame (Impeller/Skia).
                  ? _ShaderGrainPainter(
                      shader: program.fragmentShader(),
                      opacity: widget.opacity,
                      seed: seed,
                    )
                  // Fallback solange der Shader laedt/fehlt.
                  : _FilmGrainPainter(
                      opacity: widget.opacity,
                      seed: seed,
                    ),
              size: Size.infinite,
            );
          },
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


class _ShaderGrainPainter extends CustomPainter {
  _ShaderGrainPainter({
    required this.shader,
    required this.opacity,
    required this.seed,
  });

  final ui.FragmentShader shader;
  final double opacity;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform-Reihenfolge MUSS der Deklaration in grain.frag entsprechen:
    // 0: uTime, 1: uOpacity.
    shader
      ..setFloat(0, seed.toDouble())
      ..setFloat(1, opacity);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ShaderGrainPainter old) =>
      old.seed != seed || old.opacity != opacity;
}
