/// SKILL: mensaena-design (Premium-Motion / C3 Sky-Body-Bogen)
/// Sky-Body — sichtbare Sonne oder Mond mit Bloom-Glow.
/// Subtile Atmung-Animation (5s loop) erzeugt Lebendigkeit.
///
/// C3: Beim Tageszeit-Phasenwechsel (dawn→day→dusk→night) wandert
/// Sonne/Mond auf einem Bogen über den Himmel zur neuen Position
/// (statt an zwei festen Punkten zu crossfaden) und blendet dabei
/// Farbe/Größe/Mond⇆Sonne mittig ineinander. Nur auf full (intensity
/// >= 0.6) — Emil: On-Screen-Bewegung = ease-in-out, und der Übergang
/// ist seltene Atmosphäre, kein häufiges UI-Feedback, also darf er
/// ruhig 1,4 s dauern. Auf reduced/none schnappt die Position hart.
library;

import 'package:flutter/material.dart';

import '../../config/theme/cinema_theme.dart';

class SkyBody extends StatefulWidget {
  const SkyBody({required this.spec, required this.intensity, super.key});

  final SkyBodySpec spec;
  final double intensity; // 0.0 – 1.0

  @override
  State<SkyBody> createState() => _SkyBodyState();
}

class _SkyBodyState extends State<SkyBody>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _travel;

  /// Ausgangs-Spec des laufenden Übergangs (null = kein Übergang aktiv).
  SkyBodySpec? _fromSpec;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
    _travel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _fromSpec = null); // Übergang beendet
        }
      });
  }

  @override
  void didUpdateWidget(SkyBody old) {
    super.didUpdateWidget(old);
    // Nur ein echter Positionswechsel löst den Bogen aus — Intensitäts-
    // Rebuilds (gleiche Phase) nicht. Auf reduced/none (intensity < 0.6)
    // wird hart umgesetzt, kein Bogen.
    final moved = old.spec.alignment != widget.spec.alignment;
    if (moved && widget.intensity >= 0.6) {
      _fromSpec = old.spec;
      _travel.forward(from: 0);
    } else if (moved) {
      _fromSpec = null;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _travel.dispose();
    super.dispose();
  }

  /// Quadratische Bézier-Komponente (Bogen über einen angehobenen
  /// Kontrollpunkt).
  static double _quad(double p0, double p1, double p2, double t) {
    final u = 1 - t;
    return u * u * p0 + 2 * u * t * p1 + t * t * p2;
  }

  Alignment _arc(Alignment a, Alignment b, double t) {
    // Kontrollpunkt mittig, aber nach oben gezogen (y negativer = höher)
    // → Sonne/Mond steigt und sinkt wie am echten Himmel.
    final cx = (a.x + b.x) / 2;
    final cy = (a.y + b.y) / 2 - 0.6;
    return Alignment(_quad(a.x, cx, b.x, t), _quad(a.y, cy, b.y, t));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _travel]),
        builder: (_, __) {
          final breath = 0.95 + _breath.value * 0.10;
          final from = _fromSpec;
          if (from == null) {
            // Ruhezustand: nur die aktuelle Spec an ihrer Position.
            return Align(
              alignment: widget.spec.alignment,
              child: _visual(widget.spec, breath, 1.0),
            );
          }
          // Übergang: gemeinsame Bogen-Position, alte Spec aus-,
          // neue einblenden (Crossfade mittig).
          final t = Curves.easeInOut.transform(_travel.value);
          final pos = _arc(from.alignment, widget.spec.alignment, t);
          return Align(
            alignment: pos,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (t < 1.0) _visual(from, breath, 1.0 - t),
                _visual(widget.spec, breath, t),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Rendert einen Himmelskörper für [spec] mit [opacity] (Crossfade).
  Widget _visual(SkyBodySpec spec, double breath, double opacity) {
    final i = widget.intensity * opacity.clamp(0.0, 1.0);
    final d = spec.diameter * breath;
    final glowD = d * 3.2;
    return SizedBox(
      width: glowD,
      height: glowD,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _glowRing(glowD, spec.glow, i * 0.55, 0.0, 1.0),
          _glowRing(glowD * 0.6, spec.glow, i * 0.75, 0.0, 1.0),
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  spec.core.withValues(alpha: i * 0.95),
                  spec.core.withValues(alpha: i * 0.75),
                  spec.glow.withValues(alpha: i * 0.40),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: spec.isMoon ? _MoonCraters(intensity: i) : null,
          ),
        ],
      ),
    );
  }

  Widget _glowRing(double size, Color color, double alpha,
      double innerStop, double outerStop) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.4),
            Colors.transparent,
          ],
          stops: [innerStop, 0.5, outerStop],
        ),
      ),
    );
  }
}

class _MoonCraters extends StatelessWidget {
  const _MoonCraters({required this.intensity});
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MoonCraterPainter(intensity: intensity),
    );
  }
}

class _MoonCraterPainter extends CustomPainter {
  _MoonCraterPainter({required this.intensity});
  final double intensity;

  // Feste Krater-Positionen für Wiedererkennbarkeit.
  static const List<List<double>> _craters = [
    [0.30, 0.35, 0.10],
    [0.65, 0.55, 0.07],
    [0.45, 0.70, 0.05],
    [0.72, 0.30, 0.04],
    [0.25, 0.65, 0.06],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * intensity);
    for (final c in _craters) {
      canvas.drawCircle(
        Offset(size.width * c[0], size.height * c[1]),
        size.shortestSide * c[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MoonCraterPainter old) =>
      old.intensity != intensity;
}
