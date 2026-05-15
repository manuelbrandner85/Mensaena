import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Krisenmodus-Atmosphaere: Herzrot-Puls-Overlay ueber den ganzen Screen.
/// Wird vom CinemaScaffold nur eingeblendet wenn ein aktiver Crisis-State
/// vorliegt. 4-Sekunden-Zyklus, Opazitaet 0 -> 8% -> 0.
class CrisisAtmosphere extends StatefulWidget {
  const CrisisAtmosphere({super.key});

  @override
  State<CrisisAtmosphere> createState() => _CrisisAtmosphereState();
}

class _CrisisAtmosphereState extends State<CrisisAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // Pulse: 0 -> 0.08 -> 0 (sin-Halbwelle, dann pause).
          final phase = _ctrl.value;
          final pulse = phase < 0.5 ? math.sin(phase * math.pi) : 0.0;
          final opacity = pulse * 0.08;
          return Container(
            color: MnColors.herzrot.withValues(alpha: opacity),
          );
        },
      ),
    );
  }
}
