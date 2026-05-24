/// SKILL: mensaena-design
/// Glass-Card v2 — Frosted-Glass mit optionalem Phase-Akzent.
///
/// Bei `phaseTinted: true` greift sich die Card automatisch die aktuelle
/// Cinema-Phase und tönt Border + leicht den Surface (subtile Phase-Hue).
/// Das Glass-Blur bleibt, Lesbarkeit wird NICHT angetastet.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/cinema_accents.dart';
import '../../providers/cinema_provider.dart';

class GlassCard extends ConsumerWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
    this.blur = 14,
    this.tint,
    this.borderColor,
    this.phaseTinted = true,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;

  /// Wenn true (default), wird Border + Surface dezent von der aktiven
  /// Cinema-Phase getönt. Setze auf false für komplett neutrale Cards.
  final bool phaseTinted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = phaseTinted
        ? ref.watch(effectiveCinemaPhaseProvider)
        : null;
    final effectiveTint = tint ??
        (phaseTinted
            ? CinemaAccents.cardSurface(phase).withValues(alpha: 0.45)
            : AppColors.surface.withValues(alpha: 0.40));
    final effectiveBorder = borderColor ??
        (phaseTinted
            ? CinemaAccents.cardBorder(phase).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.10));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
