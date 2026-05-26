/// SKILL: mensaena-features (Dashboard-Edit)
/// Banner oben im Dashboard wenn Edit-Mode aktiv.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import 'widget_grid_settings.dart';

class DashboardEditBanner extends ConsumerWidget {
  const DashboardEditBanner({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('dashboard.edit.reset'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text('dashboard.edit.reset_confirm'.tr(),
            style: AppTypography.body(size: 14, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('dashboard.edit.reset_no'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrotWarm),
            child: Text('dashboard.edit.reset_yes'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dashboardWidgetConfigProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(LucideIcons.edit3, size: 18, color: AppColors.bronze),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('dashboard.edit.title'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              Text('dashboard.edit.hint'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft, height: 1.3)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'dashboard.edit.reset'.tr(),
          onPressed: () => _confirmReset(context, ref),
          icon: const Icon(LucideIcons.rotateCcw,
              size: 18, color: AppColors.herzrotWarm),
        ),
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(isDashboardEditModeProvider.notifier).state = false;
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.voidColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text('dashboard.edit.done'.tr()),
        ),
      ]),
    );
  }
}
