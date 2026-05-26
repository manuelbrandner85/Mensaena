/// SKILL: mensaena-features (Dashboard-Edit)
/// Chip-Bar mit deaktivierten Widgets; tap → wieder aktivieren.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import 'widget_grid_settings.dart';

class DisabledWidgetsBar extends ConsumerWidget {
  const DisabledWidgetsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardWidgetConfigProvider).maybeWhen(
          data: (c) => c,
          orElse: () => DashboardWidgetConfig.defaultConfig,
        );
    final disabled = config.disabledWidgetIds
        .map((id) => DashboardWidgetConfig.all.firstWhere(
              (w) => w.id == id,
              orElse: () => DashboardWidgetConfig.all.first,
            ))
        .where((w) => _canAdd(w))
        .toList();
    // Filter explicit: removable=false widgets sollten nicht im Disable-Pool
    // landen können (sind ohnehin nicht deaktivierbar in toggle).
    final disabledFiltered =
        disabled.where((w) => w.removable).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: AppColors.bronze.withValues(alpha: 0.35),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.plus,
                size: 16, color: AppColors.bronze),
            const SizedBox(width: 8),
            Text('dashboard.edit.add_widget'.tr(),
                style: AppTypography.label(size: 11)),
          ]),
          const SizedBox(height: 10),
          if (disabledFiltered.isEmpty)
            Row(children: [
              const Icon(LucideIcons.checkCircle2,
                  size: 14, color: AppColors.leben),
              const SizedBox(width: 6),
              Text('dashboard.edit.all_active'.tr(),
                  style: AppTypography.caption()),
            ])
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: disabledFiltered.map((w) {
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(dashboardWidgetConfigProvider.notifier)
                        .enableWidget(w.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: AppColors.surface,
                      duration: const Duration(seconds: 2),
                      content: Text('dashboard.edit.widget_enabled'.tr(),
                          style: AppTypography.body(
                              size: 13, color: AppColors.ink)),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(w.icon, size: 14, color: AppColors.bronze),
                      const SizedBox(width: 6),
                      Text(w.title.tr(),
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.ink,
                              weight: FontWeight.w600)),
                    ]),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Helper: ist das Widget "vom User entfernbar" (sonst hat es keinen Sinn
  // in der Disabled-Bar zu landen — Hero/Safety etc. sind removable=false).
  bool _canAdd(DashboardWidgetMeta w) => w.removable;
}
