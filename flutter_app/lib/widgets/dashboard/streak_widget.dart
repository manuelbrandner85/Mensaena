/// SKILL: mensaena-features + mensaena-design
/// Streak-Widget — zeigt aktuelle Login-Streak + Best-Streak.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/streak_service.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _streakProvider = FutureProvider<StreakData>((ref) async {
  return StreakService.read();
});

class StreakWidget extends ConsumerWidget {
  const StreakWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_streakProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.current <= 0) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Bloom(
                color: AppColors.amber,
                intensity: 0.5,
                radius: 12,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber.withValues(alpha: 0.18),
                    border:
                        Border.all(color: AppColors.amber, width: 1.5),
                  ),
                  child: const Icon(LucideIcons.flame,
                      size: 22, color: AppColors.amber),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('streak.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'streak.days'
                          .tr(namedArgs: {'count': '${data.current}'}),
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (data.best > data.current)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('streak.best'.tr(),
                        style: AppTypography.caption()),
                    const SizedBox(height: 2),
                    Text('${data.best}',
                        style: AppTypography.display(
                            size: 18, color: AppColors.bronze)),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
