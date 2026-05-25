/// SKILL: mensaena-features + mensaena-design
/// Help-Streak-Widget (F50): zeigt aktuelle Helping-Streak +
/// Heute-helped-Indikator.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/help_streak_service.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _helpStreakProvider = FutureProvider<HelpStreakData>((ref) async {
  return HelpStreakService.compute();
});

class HelpStreakWidget extends ConsumerWidget {
  const HelpStreakWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_helpStreakProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) {
        if (d.current <= 0) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Bloom(
                color: AppColors.leben,
                intensity: 0.55,
                radius: 12,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.leben.withValues(alpha: 0.18),
                    border:
                        Border.all(color: AppColors.leben, width: 1.5),
                  ),
                  child: const Icon(LucideIcons.helpingHand,
                      size: 22, color: AppColors.leben),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('helpStreak.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'helpStreak.days'
                          .tr(namedArgs: {'count': '${d.current}'}),
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                    if (!d.helpedToday) ...[
                      const SizedBox(height: 2),
                      Text('helpStreak.notYetToday'.tr(),
                          style: AppTypography.caption()),
                    ],
                  ],
                ),
              ),
              if (d.helpedToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.leben.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.leben.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'helpStreak.today'.tr(),
                    style: AppTypography.body(
                      size: 10,
                      color: AppColors.leben,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
