/// SKILL: mensaena-design (Cinema-Hyperreal / Premium-Motion)
/// Gestaffelte Eintritts-Animation für Listen-Items.
///
/// V24: Crash-sicher neu gebaut. Vorher (V23) nutzte es einen expliziten
/// AnimationController → bei schneller Navigation feuerte ein dangling
/// Animations-Callback auf disposed State (Crash), darum war es No-Op.
/// Jetzt: TweenAnimationBuilder — komplett selbst-verwaltet, KEIN Controller,
/// KEIN dispose-Hazard, kein Timer. Stagger über Interval-Curve pro Index.
///
/// Reduce-Motion / Lite-Tier werden vom Aufrufer berücksichtigt (oder es
/// bleibt harmlos: eine einmalige 1-Frame-Animation ohne Wiederholung).
library;

import 'package:flutter/material.dart';

class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 480),
    this.offsetY = 18,
    this.maxStagger = 10,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  /// Ab diesem Index keine zusätzliche Verzögerung mehr (verhindert dass
  /// späte Items in langen Listen ewig auf ihren Auftritt warten).
  final int maxStagger;

  /// Aufrufer kann global abschalten (z. B. reduceMotion / Lite-Tier).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final stagger = index.clamp(0, maxStagger);
    // Jedes Item bekommt ein eigenes Interval-Fenster innerhalb einer
    // gemeinsamen 0..1-Kurve. start wächst pro Index, sodass Items
    // nacheinander „hereingleiten" — ohne separate Timer.
    final start = (stagger * 0.06).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + Duration(milliseconds: stagger * 55),
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
