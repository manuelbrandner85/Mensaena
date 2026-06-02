/// SKILL: mensaena-features (F47)
/// Daily-Challenges-Widget: 3 Tages-Aufgaben mit Checkboxen + Karma-Bonus.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/mega_providers.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/haptics.dart';
import '../effects/bloom.dart';
import '../effects/celebrate_burst.dart';
import '../effects/glass_card.dart';

class DailyChallengesWidget extends ConsumerWidget {
  const DailyChallengesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayChallengesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (challenges) {
        if (challenges.isEmpty) return const SizedBox.shrink();
        final done = challenges.where((c) => c.isCompleted).length;
        final allDone = done == challenges.length;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Bloom(
                    color: AppColors.amber,
                    intensity: 0.5,
                    radius: 10,
                    child: Icon(LucideIcons.target,
                        size: 18, color: AppColors.amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('community.daily_challenges'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: allDone
                          ? AppColors.leben.withValues(alpha: 0.18)
                          : AppColors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$done/${challenges.length}',
                        style: AppTypography.body(
                          size: 10,
                          color: allDone
                              ? AppColors.leben
                              : AppColors.amber,
                          weight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final c in challenges)
                _ChallengeTile(
                  text: c.challengeText,
                  reward: c.karmaReward,
                  done: c.isCompleted,
                  onTap: () async {
                    if (c.isCompleted) return;
                    Haptics.confirm();
                    // markCompleted vergibt jetzt SERVER-seitig echtes Karma
                    // und gibt den vergebenen Betrag zurück (0 = war schon
                    // erledigt). Vorher nur lokales Flag, Karma war fiktiv.
                    final awarded =
                        await DailyChallengesRepository.markCompleted(c.id);
                    if (!context.mounted) return;
                    ref.invalidate(todayChallengesProvider);
                    if (awarded > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text(
                          'challenges.karmaAwarded'
                              .tr(namedArgs: {'n': '$awarded'}),
                          style: AppTypography.body(
                              size: 13, color: AppColors.ink),
                        ),
                      ));
                    }
                    final next =
                        await ref.read(todayChallengesProvider.future);
                    if (next.where((x) => x.isCompleted).length ==
                            next.length &&
                        context.mounted) {
                      CelebrateBurst.fire(context, ref: ref);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.text,
    required this.reward,
    required this.done,
    required this.onTap,
  });
  final String text;
  final int reward;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(
              done ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 18,
              color: done ? AppColors.leben : AppColors.mute,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body(
                  size: 12,
                  color: done ? AppColors.mute : AppColors.ink,
                  weight: done ? FontWeight.w500 : FontWeight.w600,
                ).copyWith(
                    decoration:
                        done ? TextDecoration.lineThrough : null),
              ),
            ),
            const SizedBox(width: 8),
            Text('+$reward',
                style: AppTypography.mono(
                    size: 11,
                    color: done ? AppColors.mute : AppColors.bronze,
                    weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
