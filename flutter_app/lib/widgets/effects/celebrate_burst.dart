/// SKILL: mensaena-design
/// Wiederverwendbarer Konfetti-Burst (F4) fuer Milestone-Momente:
/// Streak-7/30/100, erfolgreicher Post, erstes Trust-Rating.
///
/// Nutzung:
/// ```dart
/// CelebrateBurst.fire(context);
/// ```
/// Triggert ein 1.5s langes Konfetti-Schauer von der Bildschirmmitte aus,
/// plus Haptics.success(). Auto-disposed.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../providers/effects_gate_provider.dart';
import '../../services/haptics.dart';

class CelebrateBurst {
  const CelebrateBurst._();

  /// Feuert ein einmaliges Konfetti-Overlay im aktuellen Navigator.
  /// Default 1.5s. Haptics.success() laeuft parallel.
  /// Wenn der User Reduce-Motion aktiviert hat: nur Haptics, kein Konfetti.
  static void fire(
    BuildContext context, {
    WidgetRef? ref,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    unawaited(Haptics.success());
    // EffectsGate statt Einzel-Signal: deckt reduceMotion/seniorMode,
    // Lite-Tier UND CinemaIntensity.minimal in einem Check ab.
    if (ref != null &&
        ref.read(effectsProfileProvider) == EffectsProfile.none) {
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _CelebrationLayer(
          duration: duration,
          onDone: () => entry.remove(),
        ));
    overlay.insert(entry);
  }
}

class _CelebrationLayer extends StatefulWidget {
  const _CelebrationLayer({required this.duration, required this.onDone});

  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<_CelebrationLayer> {
  late final ConfettiController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ConfettiController(duration: widget.duration);
    _ctrl.play();
    // Ein Tick nach Ende → Overlay entfernen.
    Timer(widget.duration + const Duration(milliseconds: 800), widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _ctrl,
          blastDirection: math.pi / 2, // nach unten
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 24,
          maxBlastForce: 28,
          minBlastForce: 12,
          emissionFrequency: 0.05,
          gravity: 0.25,
          colors: const [
            AppColors.bronze,
            AppColors.amber,
            AppColors.teal,
            AppColors.lebenSoft,
            AppColors.herzrotWarm,
          ],
        ),
      ),
    );
  }
}
