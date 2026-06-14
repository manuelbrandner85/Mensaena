import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Einheitlicher Fehler-Zustand mit „Erneut versuchen". Pendant zum
/// EmptyStateWidget — überall dort, wo ein Lade-/Netzwerkfehler auftritt,
/// statt stiller Fehler, roher Exception-Texte oder leerer Flächen.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    this.title,
    this.subtitle,
    this.onRetry,
    this.icon = LucideIcons.wifiOff,
    this.compact = false,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;

  /// compact = kleinere Variante für Inline-Bereiche (z. B. in Karten/Listen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 24, vertical: compact ? 12 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: compact ? 52 : 72,
            height: compact ? 52 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.herzrot.withValues(alpha: 0.12),
            ),
            child: Icon(icon,
                size: compact ? 22 : 30, color: AppColors.herzrotWarm),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            title ?? 'errors.loadFailed'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.display(
                size: compact ? 15 : 17, color: AppColors.ink),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.55,
              ),
            ),
          ],
          if (onRetry != null) ...[
            SizedBox(height: compact ? 12 : 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.voidColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text('errors.retry'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
