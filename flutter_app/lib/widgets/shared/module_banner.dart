/// SKILL: mensaena-design (Higgsfield-Modul-Banner)
/// ModuleBanner — schlanker Header-Bildstreifen oben in jedem Modul.
///
/// Fotorealistisches Higgsfield-Keyart (assets/images/modules/*.webp) mit
/// Unten-Scrim, das nahtlos in den dunklen Content übergeht. Bewusst
/// STATISCH (kein AnimationController pro Modul → keine Perf-Last bei 20+
/// Modulen). Ladefehler → unsichtbar (SizedBox.shrink), nie Layout-Bruch.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class ModuleBanner extends StatelessWidget {
  const ModuleBanner({required this.asset, this.height = 116, super.key});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Unten-Scrim: Bild verläuft sauf den App-Hintergrund (void),
          // damit der Content ohne harte Kante anschließt.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Colors.transparent,
                    AppColors.voidColor,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
