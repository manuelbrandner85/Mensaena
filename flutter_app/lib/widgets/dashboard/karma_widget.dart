/// SKILL: mensaena-features + mensaena-design
/// Karma-Widget (F31): zeigt Punkte + aktuelles Level + Progress-Bar
/// zum naechsten Level + Breakdown (Hilfen / Posts / Bewertungen / Kommentare).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/karma_service.dart';
import 'tile_error.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _karmaProvider = FutureProvider<KarmaSnapshot>((ref) async {
  return KarmaService.compute();
});

class KarmaWidget extends ConsumerWidget {
  const KarmaWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_karmaProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(_karmaProvider)),
      data: (k) {
        if (k.points == 0) return const SizedBox.shrink();
        final level = k.level;
        final progress = k.progressInLevel;
        final toNext = k.pointsToNext;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Bloom(
                    color: AppColors.bronze,
                    intensity: 0.55,
                    radius: 14,
                    child: Icon(LucideIcons.award,
                        size: 22, color: AppColors.bronze),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('karma.title'.tr(),
                            style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(level.labelKey.tr(),
                            style: AppTypography.body(
                                size: 12, color: AppColors.bronze)),
                      ],
                    ),
                  ),
                  Text('${k.points}',
                      style: AppTypography.display(
                          size: 22, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 10),
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.line,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.bronze),
                ),
              ),
              const SizedBox(height: 6),
              if (toNext > 0)
                Text(
                  'karma.toNext'.tr(namedArgs: {'count': '$toNext'}),
                  style: AppTypography.caption(),
                )
              else
                Text('karma.maxLevel'.tr(),
                    style: AppTypography.caption()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _stat(LucideIcons.helpingHand, '${k.helps}',
                      'karma.helps'.tr()),
                  _stat(LucideIcons.fileText, '${k.posts}',
                      'karma.posts'.tr()),
                  _stat(LucideIcons.star, '${k.ratings}',
                      'karma.ratings'.tr()),
                  _stat(LucideIcons.messageSquare, '${k.comments}',
                      'karma.comments'.tr()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.mute),
        const SizedBox(width: 4),
        Text('$value $label', style: AppTypography.caption()),
      ],
    );
  }
}
