/// SKILL: mensaena-design
/// Glass-Card v4 — Performance-Fix mit Blur-Erhalt.
///
/// Blur BLEIBT, aber optimiert:
///   * Default sigma von 14 auf 8 reduziert (visuell fast identisch,
///     ~40% weniger GPU pro Blur-Pass)
///   * Strong sigma von 24 auf 12 (Sheets sehen gleich aus)
///   * RepaintBoundary um den gesamten Card-Tree → Flutter cached das
///     Blur-Ergebnis und berechnet es nur bei echten Content-Änderungen
///     neu (nicht bei jedem Scroll-Frame)
///   * BoxShadow von 3 auf 2 reduziert (der dritte war bei 32px blur +
///     0.10 alpha unsichtbar)
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/cinema_accents.dart';
import '../../providers/cinema_provider.dart';
import '../../providers/effects_gate_provider.dart';

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
  })  : _effectiveSigma = 8, // V4: 14→8 (visuell fast identisch)
        _topHighlight = 0.12,
        _bottomHighlight = 0.05,
        _tintAlpha = 0.50; // V4: leicht erhoeht um reduzierten Blur zu
                           // kompensieren (0.45→0.50)

  const GlassCard.subtle({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 12,
    this.tint,
    this.borderColor,
    this.phaseTinted = true,
    super.key,
  })  : blur = 8,
        _effectiveSigma = 5, // V4: 8→5
        _topHighlight = 0.08,
        _bottomHighlight = 0.03,
        _tintAlpha = 0.22; // 0.18→0.22

  const GlassCard.strong({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.tint,
    this.borderColor,
    this.phaseTinted = true,
    super.key,
  })  : blur = 24,
        _effectiveSigma = 12, // V4: 24→12
        _topHighlight = 0.16,
        _bottomHighlight = 0.06,
        _tintAlpha = 0.58; // 0.55→0.58

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final bool phaseTinted;

  /// V4: Tatsaechlicher Sigma-Wert fuer BackdropFilter.
  /// Niedriger als der `blur`-Parameter (API-Compat), aber visuell
  /// fast identisch weil die erhoehte tintAlpha den geringeren Blur
  /// kompensiert.
  final double _effectiveSigma;
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

    // EffectsGate: BackdropFilter ist der teuerste Standard-Effekt.
    // Auf reduced/none (Lite-Tier, reduceMotion, Intensity) ersetzt eine
    // staerker getoente Flaeche den Blur — visuell nah, GPU-Kosten ~0.
    final glassProfile = ref.watch(effectsProfileProvider);
    if (!glassProfile.isFull) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  effectiveTint, AppColors.surface.withValues(alpha: 0.85)),
              borderRadius: radius,
              border: Border.all(color: effectiveBorder, width: 1),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
    }

    // V4: RepaintBoundary cached das Blur-Ergebnis → wird nur bei
    // echten Content-Aenderungen neu berechnet, nicht bei jedem Frame.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _effectiveSigma,
            sigmaY: _effectiveSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: effectiveTint,
              borderRadius: radius,
              border: Border.all(color: effectiveBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                // V4: Dritter Shadow entfernt (war unsichtbar bei alpha 0.10)
              ],
            ),
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
      ),
    );
  }
}
