/// SKILL: mensaena-design
/// AtmosphericLayers — hyperrealistische Tiefen- und Partikel-Effekte
/// für die Cinema-Atmosphäre. Liegen IMMER hinter dem Content, niemals
/// drüber. Lesbarkeit der UI bleibt 100 % erhalten.
///
/// Layers:
///   * Starfield (Nacht): 80 Sterne mit Twinkle-Animation
///   * GroundFog (Dawn/Dusk/Evening): weicher Boden-Nebel
///   * GodRays (Dawn/Dusk + Day): volumetrische Strahlen von Sky-Body
///   * AtmosphericHaze (alle): Tiefen-Gradient (oben heller, unten dunkler)
///   * DustParticles (Dusk/Evening): driftende Staubpartikel (Sonnen-Atmosphäre)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── Atmospheric-Haze — Tiefen-Effekt zwischen Background und Content ────
class AtmosphericHaze extends StatelessWidget {
  const AtmosphericHaze({
    required this.topColor,
    required this.bottomColor,
    required this.intensity,
    super.key,
  });

  final Color topColor;
  final Color bottomColor;
  final double intensity; // 0.0 – 1.0

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              topColor.withValues(alpha: 0.15 * intensity),
              Colors.transparent,
              bottomColor.withValues(alpha: 0.20 * intensity),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Starfield — animiertes Sternen-Feld für Nacht-Phase ─────────────────
class Starfield extends StatefulWidget {
  const Starfield({
    required this.intensity,
    this.count = 80,
    super.key,
  });

  final double intensity;
  final int count;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    final rng = math.Random(42);
    _stars = List.generate(widget.count, (_) {
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.85, // oben konzentriert
        size: 0.6 + rng.nextDouble() * 1.4,
        twinkleSpeed: 0.6 + rng.nextDouble() * 1.8,
        twinklePhase: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _StarfieldPainter(
              stars: _stars,
              intensity: widget.intensity,
              t: _ctrl.value * math.pi * 2),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });
  final double x, y, size, twinkleSpeed, twinklePhase;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({
    required this.stars,
    required this.intensity,
    required this.t,
  });

  final List<_Star> stars;
  final double intensity;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final twinkle = 0.40 + 0.60 *
          (0.5 + 0.5 * math.sin(t * s.twinkleSpeed + s.twinklePhase));
      paint
        ..color = Colors.white.withValues(alpha: twinkle * intensity * 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size * 0.8);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
      // Inner core (kein Blur)
      paint
        ..maskFilter = null
        ..color = Colors.white.withValues(alpha: twinkle * intensity);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size * 0.45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) =>
      old.t != t || old.intensity != intensity;
}

// ── Ground-Fog — weicher Boden-Nebel für Dawn/Dusk/Evening ──────────────
class GroundFog extends StatelessWidget {
  const GroundFog({
    required this.color,
    required this.intensity,
    super.key,
  });

  final Color color;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.35,
          widthFactor: 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  color.withValues(alpha: 0.18 * intensity),
                  color.withValues(alpha: 0.32 * intensity),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

// ── God-Rays — volumetrische Strahlen von einem Lichtpunkt ──────────────
class GodRays extends StatefulWidget {
  const GodRays({
    required this.source,
    required this.color,
    required this.intensity,
    super.key,
  });

  final Alignment source;
  final Color color;
  final double intensity;

  @override
  State<GodRays> createState() => _GodRaysState();
}

class _GodRaysState extends State<GodRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _GodRaysPainter(
            source: widget.source,
            color: widget.color,
            intensity: widget.intensity,
            t: _ctrl.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GodRaysPainter extends CustomPainter {
  _GodRaysPainter({
    required this.source,
    required this.color,
    required this.intensity,
    required this.t,
  });

  final Alignment source;
  final Color color;
  final double intensity;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (source.x + 1) / 2;
    final cy = size.height * (source.y + 1) / 2;
    const rayCount = 14;
    final maxLen = size.longestSide * 1.4;
    for (var i = 0; i < rayCount; i++) {
      final ang = (i / rayCount) * math.pi * 2 + t * 0.15;
      final widthMul = 0.6 + 0.4 *
          (0.5 + 0.5 * math.sin(t * math.pi * 2 + i * 0.7));
      final shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.18 * intensity * widthMul),
          color.withValues(alpha: 0.06 * intensity * widthMul),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy), radius: maxLen));
      final paint = Paint()
        ..shader = shader
        ..strokeWidth = 26 * widthMul
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      final endX = cx + math.cos(ang) * maxLen;
      final endY = cy + math.sin(ang) * maxLen;
      canvas.drawLine(Offset(cx, cy), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(_GodRaysPainter old) =>
      old.t != t || old.intensity != intensity;
}

// ── DustParticles — driftende warme Staubteilchen (Dusk/Evening) ────────
class DustParticles extends StatefulWidget {
  const DustParticles({
    required this.color,
    required this.intensity,
    this.count = 35,
    super.key,
  });

  final Color color;
  final double intensity;
  final int count;

  @override
  State<DustParticles> createState() => _DustParticlesState();
}

class _DustParticlesState extends State<DustParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Dust> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    final rng = math.Random(7);
    _particles = List.generate(widget.count, (_) {
      return _Dust(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.0 + rng.nextDouble() * 2.0,
        driftSpeed: 0.4 + rng.nextDouble() * 0.6,
        driftAngle: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _DustPainter(
            particles: _particles,
            color: widget.color,
            intensity: widget.intensity,
            t: _ctrl.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Dust {
  const _Dust({
    required this.x,
    required this.y,
    required this.size,
    required this.driftSpeed,
    required this.driftAngle,
  });
  final double x, y, size, driftSpeed, driftAngle;
}

class _DustPainter extends CustomPainter {
  _DustPainter({
    required this.particles,
    required this.color,
    required this.intensity,
    required this.t,
  });

  final List<_Dust> particles;
  final Color color;
  final double intensity;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final drift = t * p.driftSpeed;
      final wx = (p.x + math.cos(p.driftAngle) * drift * 0.10) % 1.0;
      final wy = (p.y + math.sin(p.driftAngle) * drift * 0.06) % 1.0;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5);
      canvas.drawCircle(
        Offset(wx * size.width, wy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) =>
      old.t != t || old.intensity != intensity;
}
