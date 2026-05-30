/// SKILL: mensaena-design (Cinema-Hyperreal / Premium-Motion)
/// Gestaffelte Eintritts-Animation für Listen-Items.
///
/// User-Report 2026-05: 'crasht nach zweitem Tap in Navigation'. Klassisches
/// Muster: 1. Tap baut Items auf (Controllers/Timer), 2. Tap disposed sie →
/// dangling Animations-Callback feuert auf disposed State → Crash.
/// NOTBREMSE: AnimatedEntrance ist app-weit No-Op. Reine Optik, kein
/// Funktionsverlust. Reaktivierung durch Umstellen von _NO_OP = false.
library;

import 'package:flutter/material.dart';

const bool _kAnimatedEntranceEnabled = false;

class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 18,
    this.maxStagger = 8,
    super.key,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  /// Ab diesem Index keine zusätzliche Verzögerung mehr.
  final int maxStagger;

  @override
  Widget build(BuildContext context) {
    if (!_kAnimatedEntranceEnabled) return child;
    return _AnimatedEntranceImpl(
      index: index,
      duration: duration,
      offsetY: offsetY,
      maxStagger: maxStagger,
      child: child,
    );
  }
}

class _AnimatedEntranceImpl extends StatefulWidget {
  const _AnimatedEntranceImpl({
    required this.child,
    required this.index,
    required this.duration,
    required this.offsetY,
    required this.maxStagger,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;
  final int maxStagger;

  @override
  State<_AnimatedEntranceImpl> createState() => _AnimatedEntranceImplState();
}

class _AnimatedEntranceImplState extends State<_AnimatedEntranceImpl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(_curve);
    final stagger = widget.index.clamp(0, widget.maxStagger);
    if (stagger == 0) {
      _c.forward();
    } else {
      // Kein Timer/Future mehr — direkt starten, dann mit CurvedAnimation
      // den Stagger-Effekt simulieren wäre möglich, aber einfacher: alle
      // Items starten zusammen wenn _kAnimatedEntranceEnabled true.
      _c.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
