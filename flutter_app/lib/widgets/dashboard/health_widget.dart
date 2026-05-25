/// SKILL: mensaena-features + mensaena-design
/// HealthWidget — Tages-Gesundheitstipp aus dem lokalen Asset.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/health_tips_service.dart';
import '../effects/glass_card.dart';

final _tipProvider = FutureProvider<HealthTip?>((ref) async {
  return HealthTipsService.tipForToday();
});

class HealthWidget extends ConsumerWidget {
  const HealthWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_tipProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            loading: () => const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.leben),
            ),
            error: (_, __) => const Icon(LucideIcons.heart,
                color: AppColors.mute),
            data: (tip) {
              if (tip == null) {
                return const Icon(LucideIcons.heart,
                    color: AppColors.mute);
              }
              return Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _categoryColor(tip.category)
                      .withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(tip.category),
                  size: 20,
                  color: _categoryColor(tip.category),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'health.title'.tr(),
                  style: AppTypography.label(
                      size: 9, color: AppColors.mute),
                ),
                const SizedBox(height: 2),
                async.when(
                  loading: () => Text(
                    'common.loading'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.mute),
                  ),
                  error: (_, __) => Text(
                    'health.error'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.mute),
                  ),
                  data: (tip) => Text(
                    tip?.text ?? 'health.empty'.tr(),
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(HealthTipCategory c) {
    switch (c) {
      case HealthTipCategory.bewegung:
        return LucideIcons.activity;
      case HealthTipCategory.mental:
        return LucideIcons.brain;
      case HealthTipCategory.schlaf:
        return LucideIcons.moon;
      case HealthTipCategory.vorsorge:
        return LucideIcons.stethoscope;
      case HealthTipCategory.ernaehrung:
        return LucideIcons.apple;
    }
  }

  Color _categoryColor(HealthTipCategory c) {
    switch (c) {
      case HealthTipCategory.bewegung:
        return AppColors.lebenSoft;
      case HealthTipCategory.mental:
        return AppColors.bronze;
      case HealthTipCategory.schlaf:
        return AppColors.tealSoft;
      case HealthTipCategory.vorsorge:
        return AppColors.amber;
      case HealthTipCategory.ernaehrung:
        return AppColors.leben;
    }
  }
}
