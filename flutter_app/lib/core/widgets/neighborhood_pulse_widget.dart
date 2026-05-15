import 'package:flutter/material.dart';

import '../painters/neighborhood_pulse.dart';

/// Convenience-Re-Export — Painter ist als Widget bereits da, hier nur
/// alias damit Importe aus core/widgets/ konsistent bleiben.
class NeighborhoodPulseWidget extends StatelessWidget {
  final double maxRadius;
  final Color? color;
  final Duration? cycle;

  const NeighborhoodPulseWidget({
    super.key,
    this.maxRadius = 200,
    this.color,
    this.cycle,
  });

  @override
  Widget build(BuildContext context) {
    return NeighborhoodPulse(
      maxRadius: maxRadius,
      color: color ?? const Color(0xFFF59E0B),
      cycle: cycle ?? const Duration(seconds: 6),
    );
  }
}
