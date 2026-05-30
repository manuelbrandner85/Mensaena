/// SKILL: mensaena-design (Cinema-Hyperreal / Premium-Motion)
/// Gestaffelte Eintritts-Animation für Listen-Items: dezentes Fade + Slide-up,
/// pro Index leicht verzögert. Gibt Listen das hochwertige "fließt herein"-
/// Gefühl statt hartem Erscheinen. Einmalig pro Item (läuft nicht erneut).
library;

import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedEntrance extends StatefulWidget {
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

  /// Ab diesem Index keine zusätzliche Verzögerung mehr (verhindert dass
  /// lange Listen spät-sichtbare Items ewig verzögern).
  final int maxStagger;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

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
      // Timer als Feld halten + in dispose canceln. Sonst feuert ein
      // Future.delayed nach dem Dispose (schnelles Scrollen baut/disposed
      // Items laufend) und ruft forward() auf einem disposed Controller →
      // Crash. mounted-Check allein reicht nicht zuverlässig.
      _delayTimer = Timer(Duration(milliseconds: 45 * stagger), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
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
