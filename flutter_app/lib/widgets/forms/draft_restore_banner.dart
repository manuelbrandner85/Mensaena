import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Dezenter Hinweis: es existiert ein automatisch gespeicherter Entwurf.
/// „Wiederherstellen" füllt das Formular, „Verwerfen" löscht den Entwurf.
/// Bewusst ruhig gehalten (teal, keine Animation) — passt zur Motion-
/// Sparsamkeit der Create-Screens (vgl. [_prefilledBanner] in Events).
class DraftRestoreBanner extends StatelessWidget {
  const DraftRestoreBanner({
    super.key,
    required this.savedAt,
    required this.onRestore,
    required this.onDiscard,
  });

  final DateTime? savedAt;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final at = savedAt;
    final when = at != null
        ? DateFormat('dd.MM. HH:mm', context.locale.toLanguageTag())
            .format(at.toLocal())
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.history, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'drafts.restoreTitle'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.teal,
                      weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  when == null
                      ? 'drafts.restoreSubtitle'.tr()
                      : 'drafts.restoreSubtitleAt'
                          .tr(namedArgs: {'time': when}),
                  style: AppTypography.label(size: 11, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onDiscard,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('drafts.discard'.tr(),
                style: AppTypography.label(size: 12, color: AppColors.mute)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onRestore,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.voidColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('drafts.restore'.tr(),
                style: AppTypography.label(size: 12, color: AppColors.voidColor)),
          ),
        ],
      ),
    );
  }
}
