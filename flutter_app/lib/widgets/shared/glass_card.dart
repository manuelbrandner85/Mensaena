/// SKILL: mensaena-design
/// CINEMA-HYPERREAL Glass-Surfaces (Claude-Design-Handoff 2026-05).
/// Direkte Ports der CSS-Klassen .glass / .glass-strong / .card:
/// transluzenter Vertikal-Gradient + BackdropFilter-Blur + Papier-Border.
///
/// Blur wird bewusst sparsam eingesetzt (GPU) — nur für prominente,
/// nicht-scrollende Flächen wie Bottom-Sheets verwenden.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

/// Generische Glass-Card (Design `.card`).
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.blur = 16,
    this.strong = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  /// `.glass-strong`-Variante (für Sheets/Overlays).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = strong
        ? const [Color(0xD6141C28), Color(0xEB080C14)]
        : const [Color(0xB8121A28), Color(0xC7080C14)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: strong ? const Color(0x47ECE5D6) : AppColors.line,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass-Container für die obere Kante eines Bottom-Sheets
/// (`.glass-strong` mit nur oben abgerundeten Ecken).
class GlassSheet extends StatelessWidget {
  const GlassSheet({required this.child, this.blur = 20, super.key});

  final Widget child;
  final double blur;

  /// Bequemer Ersatz für showModalBottomSheet im Glass-Strong-Design:
  /// transparenter Hintergrund + GlassSheet-Wrapper. [builder] liefert den
  /// Sheet-Inhalt (typischerweise SafeArea + Padding + Column).
  static Future<T?> show<T>(
    BuildContext context,
    Widget Function(BuildContext) builder, {
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (ctx) => GlassSheet(child: builder(ctx)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD6141C28), Color(0xEB080C14)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: Color(0x47ECE5D6)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
