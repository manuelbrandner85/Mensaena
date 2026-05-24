/// SKILL: mensaena-design
/// Glass-Card v3 — Frosted-Glass im Apple-Style mit mehrschichtigem Look.
///
/// Anatomie:
///   1. BackdropFilter (Gaussian-Blur, sigma steuerbar)
///   2. Phase- oder neutrale Tint-Fläche
///   3. Linear-Gradient-Overlay (oben hell, unten dunkler) für Glas-Look
///   4. 1px Border in Weiß-Alpha für Lichtkante
///
/// WANN NUTZEN:
///   - ÜBER einer Cinema-Atmosphäre / Hintergrund-Photo / Sky-Body / Gradient.
///   - NICHT auf einfarbigem Surface — dort wirkt das Frosted-Glas tot.
///
/// Bei `phaseTinted: true` greift sich die Card automatisch die aktuelle
/// Cinema-Phase und tönt Border + leicht den Surface (subtile Phase-Hue).
/// Das Glass-Blur bleibt, Lesbarkeit wird NICHT angetastet.
///
/// Variants:
///   - `GlassCard()`            — Default (14px blur, 45% tint)
///   - `GlassCard.subtle()`     — 8px blur, 6% tint (für Inputs, Inline-Cards)
///   - `GlassCard.strong()`     — 24px blur, 18% tint (für Sheets, Modals)
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
  })  : blurSigma = blur,
        _topHighlight = 0.12,
        _bottomHighlight = 0.05,
        _tintAlpha = 0.45;

  /// Subtle-Variant — leichtes Blur, kaum Tint. Für Inline-Inputs,
  /// kleine Glas-Pille-Buttons, Hover-Cards. 8px blur.
  const GlassCard.subtle({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 12,
    this.tint,
    this.borderColor,
    this.phaseTinted = true,
    super.key,
  })  : blur = 8,
        blurSigma = 8,
        _topHighlight = 0.08,
        _bottomHighlight = 0.03,
        _tintAlpha = 0.18;

  /// Strong-Variant — kräftiges Blur, deutliches Frosted. Für Bottom-Sheets,
  /// Modals, AppBar-Overlays. 24px blur.
  const GlassCard.strong({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.tint,
    this.borderColor,
    this.phaseTinted = true,
    super.key,
  })  : blur = 24,
        blurSigma = 24,
        _topHighlight = 0.16,
        _bottomHighlight = 0.06,
        _tintAlpha = 0.55;

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;

  /// Alias für `blur` — semantisch klarer in API-Calls.
  final double blurSigma;
  final Color? tint;
  final Color? borderColor;

  /// Wenn true (default), wird Border + Surface dezent von der aktiven
  /// Cinema-Phase getönt. Setze auf false für komplett neutrale Cards.
  final bool phaseTinted;

  final double _topHighlight;
  final double _bottomHighlight;
  final double _tintAlpha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = phaseTinted
        ? ref.watch(effectiveCinemaPhaseProvider)
        : null;
    final effectiveTint = tint ??
        (phaseTinted
            ? CinemaAccents.cardSurface(phase).withValues(alpha: _tintAlpha)
            : AppColors.surface.withValues(alpha: _tintAlpha));
    final effectiveBorder = borderColor ??
        (phaseTinted
            ? CinemaAccents.cardBorder(phase).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.12));

    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: radius,
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
          // 2. Layer: Linear-Gradient-Overlay (oben heller, unten dunkler)
          // simuliert den Lichtfall auf einer Glas-Oberfläche.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: _topHighlight),
                  Colors.white.withValues(alpha: _bottomHighlight),
                ],
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
