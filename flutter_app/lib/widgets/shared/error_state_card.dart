/// SKILL: mensaena-design
/// Wiederverwendbarer Error-State mit Retry-Button.
///
/// Vorher: viele Screens zeigten bei AsyncError nur `Text('$e')` —
/// User sah technische Exception ohne Aktion. Jetzt: lokalisierte
/// Message + Retry-Callback.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    this.message,
    this.onRetry,
    this.icon = LucideIcons.alertTriangle,
    super.key,
  });

  /// Optional eigene Message (default: lokalisiertes 'common.errorGeneric').
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final msg = message ?? 'common.errorGeneric'.tr();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.herzrotWarm.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.herzrotWarm),
          const SizedBox(height: 10),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text('common.retry'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
