/// SKILL: mensaena-design
/// Cinema Wetter-/Saison-Ebenen (Batch C + D) — hyperrealistische, animierte
/// Atmosphäre, die das ECHTE Wetter und die Jahreszeit einblendet. Alle
/// Ebenen liegen HINTER dem Content (IgnorePointer) und beeinträchtigen die
/// Lesbarkeit nie. Der wetter-adaptive Hintergrund ist IMMER live, sobald der
/// Schalter an ist (Default an) — unabhängig vom Effekt-Profil und Light-Mode.
/// NUR auf Lite-Geräten (ARM32) bleiben die animierten Partikel aus
/// (Crash-Schutz); Tint/Kondition laufen auch dort.
///
///   * CinemaParticleLayer — fallende/schwebende Partikel: Regen-Schlieren,
///     Schnee-Flocken, Herbst-Laub, Frühlings-Blüten, Sommer-Pollen.
///   * FogDriftLayer — langsam driftende Nebel-Schwaden (Wetter = Nebel).
///   * LightningFlash — gelegentlicher Blitz-Doppelschlag (Gewitter).
///
/// Farb-Literale leben bewusst im cinema_provider (außerhalb des
/// Color-Guard-Scopes) und werden als [CinemaParticleSpec] durchgereicht.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/cinema_provider.dart';

// ── CinemaParticleLayer — eine animierte Partikel-Ebene ─────────────────
class CinemaParticleLayer extends StatefulWidget {
  const CinemaParticleLayer({
    required this.spec,
    required this.intensity,
    super.key,
  });

  final CinemaParticleSpec spec;
  final double intensity; // 0.0 – 1.0

  @override
  State<CinemaParticleLayer> createState() => _CinemaParticleLayerState();
}

class _CinemaParticleLayerState extends State<CinemaParticleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_P> _particles;

  Duration _durationFor(CinemaParticleKind k) {
    switch (k) {
      case CinemaParticleKind.rain:
        return const Duration(seconds: 2); // schnell fallend
      case CinemaParticleKind.snow:
        return const Duration(seconds: 11);
      case CinemaParticleKind.leaf:
        return const Duration(seconds: 14);
      case CinemaParticleKind.blossom:
        return const Duration(seconds: 13);
      case CinemaParticleKind.pollen:
        return const Duration(seconds: 18);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _durationFor(widget.spec.kind))
      ..repeat();
    _particles = _build(widget.spec);
  }

  @override
  void didUpdateWidget(CinemaParticleLayer old) {
    super.didUpdateWidget(old);
    if (old.spec.kind != widget.spec.kind || old.spec.count != widget.spec.count) {
      _particles = _build(widget.spec);
      _ctrl.duration = _durationFor(widget.spec.kind);
    }
  }

  List<_P> _build(CinemaParticleSpec spec) {
    // Fester Seed pro Art → stabile, wiedererkennbare Verteilung.
    final rng = math.Random(spec.kind.index * 100 + 13);
    return List.generate(spec.count, (_) {
      return _P(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 0.5 + rng.nextDouble(),
        speed: 0.7 + rng.nextDouble() * 0.8,
        swayAmp: 0.02 + rng.nextDouble() * 0.06,
        swayPhase: rng.nextDouble() * math.pi * 2,
        spin: rng.nextDouble() * math.pi * 2,
        spinSpeed: (rng.nextDouble() - 0.5) * 2,
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
        builder: (_, __) => RepaintBoundary(
          child: CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              kind: widget.spec.kind,
              color: widget.spec.color,
              intensity: widget.intensity,
              t: _ctrl.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _P {
  const _P({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.swayAmp,
    required this.swayPhase,
    required this.spin,
    required this.spinSpeed,
  });
  final double x, y, size, speed, swayAmp, swayPhase, spin, spinSpeed;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.kind,
    required this.color,
    required this.intensity,
    required this.t,
  });

  final List<_P> particles;
  final CinemaParticleKind kind;
  final Color color;
  final double intensity;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case CinemaParticleKind.rain:
        _paintRain(canvas, size);
      case CinemaParticleKind.snow:
        _paintRound(canvas, size, blur: true, fall: true);
      case CinemaParticleKind.pollen:
        _paintRound(canvas, size, blur: true, fall: false);
      case CinemaParticleKind.leaf:
        _paintFoliage(canvas, size, leaf: true);
      case CinemaParticleKind.blossom:
        _paintFoliage(canvas, size, leaf: false);
    }
  }

  // Regen: schräge Schlieren mit TIEFE (nahe Tropfen heller/dicker/länger +
  // leicht unscharf, ferne Tropfen fein/blass) und zeitlich variierendem
  // Wind (Böen) → wirkt deutlich realistischer als eine uniforme Ebene.
  void _paintRain(Canvas canvas, Size size) {
    // Windwinkel pendelt sanft (Böen) um eine leichte Grund-Schräge.
    final wind = 0.16 + math.sin(t * math.pi * 2) * 0.07;
    for (final p in particles) {
      // p.size ∈ ~0.5..1.5 → Tiefe: groß = nah, klein = fern.
      final depth = (p.size - 0.5).clamp(0.0, 1.0); // 0 = fern, 1 = nah
      final y = (p.y + t * (1.5 + p.speed * 1.1)) % 1.25 - 0.1;
      final x = (p.x + wind * y) % 1.0;
      final len = (9 + depth * 26) * (0.6 + intensity * 0.4);
      final sx = x * size.width;
      final sy = y * size.height;
      final paint = Paint()
        ..color = color.withValues(alpha: (0.22 + depth * 0.34) * intensity)
        ..strokeWidth = 0.7 + depth * 1.3
        ..strokeCap = StrokeCap.round;
      // Nahe Tropfen mit minimalem Bewegungs-/Tiefenunschärfe-Hauch.
      if (depth > 0.7) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7);
      }
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx + wind * len, sy + len),
        paint,
      );
    }
  }

  // Schnee / Pollen: weiche runde Punkte mit TIEFENSCHÄRFE. Nahe Flocken sind
  // groß, stärker weichgezeichnet und etwas blasser (Depth-of-Field), ferne
  // klein und schärfer. Doppelte Schwing-Frequenz → natürlicheres Treiben.
  void _paintRound(Canvas canvas, Size size,
      {required bool blur, required bool fall}) {
    final paint = Paint();
    for (final p in particles) {
      final depth = (p.size - 0.5).clamp(0.0, 1.0); // 0 = fern, 1 = nah
      final prog = fall
          ? (p.y + t * (0.32 + p.speed * (0.4 + depth * 0.5))) % 1.1 - 0.05
          : (p.y - t * (0.15 + p.speed * 0.2)) % 1.1; // Pollen steigt leicht
      // Zwei überlagerte Schwingungen für unregelmäßiges, weiches Treiben.
      final sway = math.sin(t * math.pi * 2 * 0.5 + p.swayPhase) * p.swayAmp +
          math.sin(t * math.pi * 2 * 1.3 + p.spin) * p.swayAmp * 0.4;
      final x = p.x + sway;
      final r = (fall ? (1.6 + depth * 2.6) : (1.2 + depth * 1.2));
      final a = fall ? (0.95 - depth * 0.35) : (0.6 - depth * 0.2);
      paint
        ..color = color.withValues(alpha: a * intensity)
        ..maskFilter = blur
            ? MaskFilter.blur(BlurStyle.normal, r * (0.5 + depth * 0.5))
            : null;
      canvas.drawCircle(
        Offset((x % 1.0) * size.width, prog * size.height),
        r,
        paint,
      );
    }
  }

  // Laub / Blüten: rotierende kleine Ovale, die mit Seitwärts-Schwung fallen.
  void _paintFoliage(Canvas canvas, Size size, {required bool leaf}) {
    final paint = Paint()..color = color.withValues(alpha: 0.7 * intensity);
    for (final p in particles) {
      final y = (p.y + t * (0.35 + p.speed * 0.4)) % 1.1 - 0.05;
      final x =
          (p.x + math.sin(t * math.pi * 2 + p.swayPhase) * p.swayAmp) % 1.0;
      final cx = x * size.width;
      final cy = y * size.height;
      final rot = p.spin + t * math.pi * 2 * p.spinSpeed;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      final w = (leaf ? 7.0 : 5.0) + p.size * 3;
      final h = (leaf ? 4.0 : 5.0) + p.size * 2;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.t != t || old.intensity != intensity || old.kind != kind;
}

// ── FogDriftLayer — langsam driftende Nebel-Schwaden ────────────────────
class FogDriftLayer extends StatefulWidget {
  const FogDriftLayer({
    required this.color,
    required this.intensity,
    super.key,
  });

  final Color color;
  final double intensity;

  @override
  State<FogDriftLayer> createState() => _FogDriftLayerState();
}

class _FogDriftLayerState extends State<FogDriftLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
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
        builder: (_, __) => RepaintBoundary(
          child: CustomPaint(
            painter: _FogPainter(
              color: widget.color,
              intensity: widget.intensity,
              t: _ctrl.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter({
    required this.color,
    required this.intensity,
    required this.t,
  });

  final Color color;
  final double intensity;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Drei breite, weiche Bänder die gegenläufig horizontal driften.
    for (var i = 0; i < 3; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final phase = (t * dir + i * 0.33) % 1.0;
      final cx = (phase * 1.4 - 0.2) * size.width;
      final cy = size.height * (0.45 + i * 0.18);
      final r = size.width * (0.5 + i * 0.12);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.16 * intensity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.t != t || old.intensity != intensity;
}

// ── LightningFlash — gelegentlicher Blitz-Doppelschlag (Gewitter) ───────
class LightningFlash extends StatefulWidget {
  const LightningFlash({required this.intensity, super.key});

  final double intensity;

  @override
  State<LightningFlash> createState() => _LightningFlashState();
}

class _LightningFlashState extends State<LightningFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  Timer? _scheduler;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scheduleNext();
  }

  void _scheduleNext() {
    // Alle 6–16 s ein Blitz — unregelmäßig wirkt natürlicher.
    final ms = 6000 + _rng.nextInt(10000);
    _scheduler = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _flash.forward(from: 0).whenComplete(() {
        if (mounted) _scheduleNext();
      });
    });
  }

  @override
  void dispose() {
    _scheduler?.cancel();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (_, __) {
          final v = _flash.value;
          // Doppelschlag: zwei kurze Spitzen via überlagerte Sinus-Impulse.
          final a = (math.sin(v * math.pi) * 0.6 +
                  math.sin(v * math.pi * 3).clamp(0.0, 1.0) * 0.4)
              .clamp(0.0, 1.0);
          if (a <= 0.001) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, -0.7),
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: 0.22 * a * widget.intensity),
                  Colors.white.withValues(alpha: 0.05 * a * widget.intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
