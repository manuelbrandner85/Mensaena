/// SKILL: mensaena-design
/// ErrorRetryCard — einheitlicher Lade-Fehler-Zustand mit "Erneut
/// versuchen"-Button, statt leerem Screen oder stillem Fehlschlag.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class ErrorRetryCard extends StatelessWidget {
  const ErrorRetryCard({
    required this.onRetry,
    this.message,
    super.key,
  });

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cloudOff, size: 40, color: AppColors.mute),
            const SizedBox(height: 12),
            Text(
              message ?? 'errors.loadFailed'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text('errors.retry'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bronze,
                side: BorderSide(
                    color: AppColors.bronze.withValues(alpha: 0.5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
