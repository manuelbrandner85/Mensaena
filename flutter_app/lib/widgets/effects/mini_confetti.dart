/// SKILL: mensaena-design
/// Mini-Konfetti — kleiner einmaliger Bronze-/Amber-Burst nach
/// erfolgreichen Submits (Post erstellt, Hilfe angeboten, RSVP, …).
/// Pure CustomPaint, keine externe Dependency, Lite-Mode-bewusst:
/// auf alten Geräten wird der Effekt komplett übersprungen — der
/// Erfolg kommuniziert sich dann über Haptik + Snackbar.
///
/// Verwendung:
///   MiniConfetti.show(context);   // 1× im Overlay, 800ms Lebensdauer
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../providers/effects_gate_provider.dart';

class MiniConfetti {
  const MiniConfetti._();

  /// Zeigt einen 800-ms-Konfetti-Burst über dem aktuellen Overlay.
  /// Sicher überall aufrufbar (z.B. nach Haptics.success() in einem
  /// async Submit-Handler), Lite-Mode-No-Op.
  static void show(BuildContext context) {
    // ProviderScope-Container holen → Lite-Mode-Check ohne ConsumerWidget.
    // ProviderScope.containerOf erwartet erstmal listen=false damit kein
    // unnötiger Listener aufgebaut wird.
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      // EffectsGate: deckt Lite-Tier, reduceMotion/seniorMode und
      // CinemaIntensity.minimal in einem Check ab.
      if (container.read(effectsProfileProvider) == EffectsProfile.none) {
        return;
      }
    } catch (_) {
      // Falls aus irgendeinem Grund kein ProviderScope da ist (Tests):
      // einfach den Effekt zeigen — kein Showstopper.
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => const IgnorePointer(child: _ConfettiBurst()),
    );
    overlay.insert(entry);
    // 900ms damit Animation sicher fertig ist bevor wir entfernen.
    Future<void>.delayed(const Duration(milliseconds: 900), entry.remove);
  }
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Particle> _particles;
  double _t = 0;
  final _start = DateTime.now();

  // 24 Partikel — sichtbar genug, kein Frame-Killer.
  static const _count = 24;
  static const _palette = [
    AppColors.bronze,
    AppColors.amber,
    AppColors.tealSoft,
    AppColors.leben,
  ];

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    _particles = List.generate(_count, (i) {
      final angle = (math.pi * 2) * (i / _count) +
          (rand.nextDouble() - 0.5) * 0.4;
      final speed = 160.0 + rand.nextDouble() * 140.0;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: _palette[rand.nextInt(_palette.length)],
        size: 4.0 + rand.nextDouble() * 4.0,
        spin: (rand.nextDouble() - 0.5) * 8.0,
      );
    });
    _ticker = createTicker((_) {
      final ms = DateTime.now().difference(_start).inMilliseconds;
      final t = (ms / 800).clamp(0.0, 1.0);
      if (mounted) setState(() => _t = t);
      if (t >= 1.0) _ticker.stop();
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return CustomPaint(
      size: size,
      painter: _ConfettiPainter(particles: _particles, t: _t, screen: size),
    );
  }
}

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
  });
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.screen,
  });
  final List<_Particle> particles;
  final double t;
  final Size screen;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = screen.width / 2;
    // Burst-Ursprung knapp unter der Bildschirmmitte (typische Button-Höhe).
    final cy = screen.height * 0.55;
    // Schwerkraft + Easing: erst nach oben/außen, dann fallend.
    final gravity = 320.0 * t * t;
    final fade = (1.0 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = cx + p.vx * t;
      final y = cy + p.vy * t + gravity;
      final angle = p.spin * t;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      // Schmaler Rechteck-Strip = klassisches Konfetti-Look.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size * 1.8, height: p.size * 0.7),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t || old.particles != particles;
}
