/// SKILL: mensaena-design (Cinema-Hyperreal / Higgsfield-Assets)
/// CinematicBackdrop — fotorealistischer Stimmungs-Hintergrund.
///
/// Zeigt eines der gebündelten Higgsfield-Stills (assets/images/*.webp,
/// Dusk-Diorama-Look passend zu AppColors) als Cover-Hintergrund mit
/// Lesbarkeits-Scrim. EffectsGate-integriert:
///   full    → langsamer Ken-Burns-Drift (Scale 1.0→1.05 über 16 s)
///   reduced → statisches Bild mit Scrim
///   none    → statisches Bild (keine Animation)
/// Ladefehler → reiner voidColor-Hintergrund, niemals Leere/Crash.
///
/// Das passende Splash-Loop-VIDEO (assets/videos/splash_dusk.mp4, Frame 1
/// = splash_dusk.webp) liegt im Repo bereit, wird aber erst mit dem
/// geplanten Version-Bump (video_player) aktiviert — dieses Widget ist
/// dann sein Fallback-Pfad.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../providers/effects_gate_provider.dart';

class CinematicBackdrop extends ConsumerStatefulWidget {
  const CinematicBackdrop({
    required this.asset,
    this.topScrim = 0.35,
    this.bottomScrim = 0.85,
    super.key,
  });

  /// Asset-Pfad, z. B. 'assets/images/splash_dusk.webp'.
  final String asset;

  /// Scrim-Stärke (0–1) oben/unten — unten stärker, weil dort Text liegt.
  final double topScrim;
  final double bottomScrim;

  @override
  ConsumerState<CinematicBackdrop> createState() => _CinematicBackdropState();
}

class _CinematicBackdropState extends ConsumerState<CinematicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(effectsProfileProvider);
    final animate = profile.isFull;
    if (animate && !_drift.isAnimating) {
      _drift.repeat(reverse: true);
    } else if (!animate && _drift.isAnimating) {
      _drift.stop();
    }

    final image = Image.asset(
      widget.asset,
      fit: BoxFit.cover,
      // memCacheWidth-Disziplin wie app-weit: Quelle ist bereits 1080/1600px,
      // kein weiteres Downscaling noetig — aber Fehler duerfen nie durchschlagen.
      errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.voidColor),
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (animate)
            AnimatedBuilder(
              animation: _drift,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + _drift.value * 0.05,
                child: child,
              ),
              child: image,
            )
          else
            image,
          // Lesbarkeits-Scrim: oben sanft, unten kraeftig (Text-Zone).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.voidColor.withValues(alpha: widget.topScrim),
                  AppColors.voidColor.withValues(alpha: 0.15),
                  AppColors.voidColor.withValues(alpha: widget.bottomScrim),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
