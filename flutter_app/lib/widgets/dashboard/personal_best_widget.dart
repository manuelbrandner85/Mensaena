/// SKILL: mensaena-features + mensaena-design
/// Personal-Best-Widget (F46): Lifetime-Spitzenwerte als motivierende Tiles.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/personal_best_service.dart';
import '../effects/glass_card.dart';

final _personalBestProvider = FutureProvider<PersonalBest>((ref) async {
  return PersonalBestService.compute();
});

class PersonalBestWidget extends ConsumerWidget {
  const PersonalBestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_personalBestProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (b) {
        final total =
            b.totalHelps + b.totalPosts + b.totalComments + b.bestLoginStreak;
        if (total == 0) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trophy,
                      size: 18, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Text('personalBest.title'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('personalBest.subtitle'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      icon: LucideIcons.helpingHand,
                      value: b.totalHelps,
                      label: 'personalBest.helps'.tr(),
                      color: AppColors.leben,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      icon: LucideIcons.fileText,
                      value: b.totalPosts,
                      label: 'personalBest.posts'.tr(),
                      color: AppColors.bronze,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      icon: LucideIcons.flame,
                      value: b.bestLoginStreak,
                      label: 'personalBest.streak'.tr(),
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      icon: LucideIcons.zap,
                      value: b.bestSingleDayActions,
                      label: 'personalBest.bestDay'.tr(),
                      color: AppColors.tealSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: AppTypography.display(
                        size: 20, color: AppColors.ink)),
                Text(label,
                    style: AppTypography.caption(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
