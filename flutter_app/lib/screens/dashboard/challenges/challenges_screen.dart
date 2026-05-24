import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/challenge.dart';
import '../../../models/challenge_progress.dart';
import '../../../repositories/challenges_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Aktive Challenges + Fortschritt des Users.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(activeChallengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    return DashboardScaffold(
      title: 'challenges.screenTitle'.tr(),
      currentRoute: '/dashboard/challenges',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(activeChallengesProvider);
            ref.invalidate(myChallengeProgressProvider);
            await ref.read(activeChallengesProvider.future);
          },
          child: challengesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (_, __) => _emptyState('Fehler beim Laden.'),
            data: (challenges) {
              if (challenges.isEmpty) {
                return _emptyState('Aktuell keine aktiven Challenges.');
              }
              final progressMap = <String, ChallengeProgress>{
                for (final p in progressAsync.value ?? const <ChallengeProgress>[])
                  p.challengeId: p,
              };
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.target,
                            color: AppColors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('challenges.title'.tr(),
                                style: AppTypography.display(
                                  size: 22,
                                  color: AppColors.ink,
                                )),
                            Text(
                              'Mach mit, sammle Punkte, verdiene Badges.',
                              style: AppTypography.caption(),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/dashboard/badges'),
                        icon: const Icon(LucideIcons.award,
                            size: 14, color: AppColors.amber),
                        label: Text('challenges.badges'.tr(),
                            style: AppTypography.label(
                              size: 10,
                              color: AppColors.amber,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...challenges.map((c) => _ChallengeTile(
                        challenge: c,
                        progress: progressMap[c.id],
                        onJoin: () async {
                          final ok = await ChallengesRepository.join(c.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: AppColors.surface,
                            content: Text(
                              ok
                                  ? 'Du bist dabei!'
                                  : 'Konnte nicht beitreten.',
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                              ),
                            ),
                          ));
                          if (ok) {
                            ref.invalidate(myChallengeProgressProvider);
                          }
                        },
                      )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              const Icon(LucideIcons.target,
                  size: 32, color: AppColors.mute),
              const SizedBox(height: 10),
              Text(
                msg,
                style:
                    AppTypography.body(size: 14, color: AppColors.mute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.challenge,
    required this.onJoin,
    this.progress,
  });

  final Challenge challenge;
  final ChallengeProgress? progress;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final current = progress?.currentCount ?? 0;
    final ratio = challenge.targetCount > 0
        ? (current / challenge.targetCount).clamp(0.0, 1.0)
        : 0.0;
    final completed = progress?.completed ?? false;
    final isJoined = progress != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(challenge.type,
                    style: AppTypography.label(size: 9)),
              ),
              const Spacer(),
              if (challenge.pointsReward != null)
                Text('+${challenge.pointsReward} P',
                    style: AppTypography.mono(
                      size: 13,
                      color: AppColors.amber,
                    )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.title,
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (challenge.description != null) ...[
            const SizedBox(height: 4),
            Text(
              challenge.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? AppColors.leben : AppColors.amber,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$current / ${challenge.targetCount}',
                style: AppTypography.mono(
                  size: 11,
                  color: AppColors.inkSoft,
                ),
              ),
              const Spacer(),
              if (completed)
                Text('✓ Erledigt',
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.lebenSoft,
                    ))
              else if (!isJoined)
                TextButton(
                  onPressed: onJoin,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 28),
                    backgroundColor:
                        AppColors.amber.withValues(alpha: 0.16),
                  ),
                  child: Text('challenges.join'.tr(),
                      style: AppTypography.label(
                        size: 10,
                        color: AppColors.amber,
                      )),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
