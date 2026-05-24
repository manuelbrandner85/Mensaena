/// SKILL: mensaena-design
/// Bloom — Outer-Glow-Helper für Akzent-Elemente (Buttons, FAB, Live-Dots).
/// Wickelt ein Child mit 3-Layer-BoxShadow für echtes Leucht-Gefühl.
library;

import 'package:flutter/material.dart';

class Bloom extends StatelessWidget {
  const Bloom({
    required this.child,
    required this.color,
    this.intensity = 1.0,
    this.radius = 24,
    super.key,
  });

  final Widget child;
  final Color color;

  /// 0.0 – 1.0. Skaliert alpha-Werte aller 3 Shadow-Layer.
  final double intensity;

  /// Basis-Radius. Inner-Layer = 0.4×, Mid = 0.8×, Outer = 1.5×.
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.01) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          // Inner — sharp & bright
          BoxShadow(
            color: color.withValues(alpha: 0.55 * intensity),
            blurRadius: radius * 0.4,
          ),
          // Mid
          BoxShadow(
            color: color.withValues(alpha: 0.30 * intensity),
            blurRadius: radius * 0.8,
          ),
          // Outer — soft halo
          BoxShadow(
            color: color.withValues(alpha: 0.15 * intensity),
            blurRadius: radius * 1.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Pulsierender Bloom — atmet 1.8s zyklisch.
class PulseBloom extends StatefulWidget {
  const PulseBloom({
    required this.child,
    required this.color,
    this.radius = 24,
    this.minIntensity = 0.4,
    this.maxIntensity = 1.0,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double minIntensity;
  final double maxIntensity;

  @override
  State<PulseBloom> createState() => _PulseBloomState();
}

class _PulseBloomState extends State<PulseBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final i = widget.minIntensity +
            _ctrl.value * (widget.maxIntensity - widget.minIntensity);
        return Bloom(
          color: widget.color,
          intensity: i,
          radius: widget.radius,
          child: widget.child,
        );
      },
    );
  }
}
