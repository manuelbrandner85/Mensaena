/// SKILL: mensaena-design
/// Glass-Card — Frosted-Glass-Container für hyperrealistisches UI.
/// BackdropFilter-Blur + Semi-Transparent-Fill + Hairline-Border.
/// Ersetzt flache Container-Schatten durch räumliche Tiefe.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
    this.blur = 14,
    this.tint,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;

  /// Default: Surface mit 0.40 alpha.
  final Color? tint;

  /// Default: weiße Hairline (0.10 alpha) für echten Glass-Look.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? AppColors.surface.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            // 3-Layer-Depth-Shadow (sharp + mid + diffuse)
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
