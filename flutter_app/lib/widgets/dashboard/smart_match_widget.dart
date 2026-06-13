/// SKILL: mensaena-features
/// SmartMatchWidget — Top 3 pending Match-Vorschlaege.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../shared/pressable.dart';
import '../../repositories/matching_repository.dart';
import 'tile_error.dart';

class SmartMatchWidget extends ConsumerWidget {
  const SmartMatchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchingListProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(matchingListProvider)),
      data: (matches) {
        final pending =
            matches.where((m) => m.status == 'pending').take(3).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        // B1 Mikro-Physik: ganze Karte = Pressable (Spring + Haptik).
        return Pressable(
          onTap: () => context.go('/dashboard/matching'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tealSoft.withValues(alpha: 0.12),
                  AppColors.amber.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                  color: AppColors.tealSoft.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles,
                        color: AppColors.tealSoft, size: 14),
                    const SizedBox(width: 6),
                    Text('home.smartMatch'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.tealSoft)),
                    const Spacer(),
                    Text('${pending.length} offen',
                        style: AppTypography.label(
                            size: 9, color: AppColors.mute)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final m in pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.teal.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(m.matchScore * 100).toInt()}%',
                            style: AppTypography.mono(
                                size: 10, color: AppColors.tealSoft),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.requestPost.title.isNotEmpty
                                ? m.requestPost.title
                                : m.offerPost.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.ink),
                          ),
                        ),
                        if (m.distanceKm != null)
                          Text('${m.distanceKm!.toStringAsFixed(0)} km',
                              style: AppTypography.caption()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
