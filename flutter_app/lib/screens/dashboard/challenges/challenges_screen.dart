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
import '../../../widgets/shared/error_state_widget.dart';

String _localizedCategory(String? cat) {
  if (cat == null) return '—';
  return 'challenges.cat.$cat'.tr();
}

String _localizedDifficulty(String? diff) {
  if (diff == null) return '—';
  return 'challenges.diff.$diff'.tr();
}

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
            error: (_, __) => Center(
              child: ErrorStateWidget(
                onRetry: () {
                  ref.invalidate(activeChallengesProvider);
                  ref.invalidate(myChallengeProgressProvider);
                },
              ),
            ),
            data: (challenges) {
              if (challenges.isEmpty) {
                return _emptyState('challenges.emptyActive'.tr());
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
                              'challenges.subtitle'.tr(),
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
                                  ? 'challenges.joinSuccess'.tr()
                                  : 'challenges.joinFailed'.tr(),
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
                        onUpdateProgress: () async {
                          final prog = progressMap[c.id];
                          if (prog == null) return;
                          final newPct =
                              await _showProgressDialog(context, prog);
                          if (newPct == null || !context.mounted) return;
                          final ok = await ChallengesRepository.updateProgress(
                              c.id, newPct);
                          if (!context.mounted) return;
                          final isCompleted = newPct >= 100;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: AppColors.surface,
                            content: Text(
                              ok
                                  ? (isCompleted
                                      ? 'challenges.autoCompleted'.tr()
                                      : 'challenges.progressUpdated'.tr())
                                  : 'challenges.progressFailed'.tr(),
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

  Future<int?> _showProgressDialog(
      BuildContext context, ChallengeProgress prog) async {
    return showDialog<int>(
      context: context,
      builder: (_) => _ProgressDialog(initialPct: prog.progressPct),
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

class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.initialPct});
  final int initialPct;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialPct.toDouble().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _value.round();
    return AlertDialog(
      backgroundColor: AppColors.elevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'challenges.updateProgress'.tr(),
        style: AppTypography.body(
          size: 16,
          color: AppColors.ink,
          weight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'challenges.progressLabel'.tr(namedArgs: {'pct': '$pct'}),
            style: AppTypography.mono(size: 28, color: AppColors.amber),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.amber,
              inactiveTrackColor: AppColors.line,
              thumbColor: AppColors.amber,
              overlayColor: AppColors.amberGlow,
            ),
            child: Slider(
              value: _value,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr(),
              style: AppTypography.label(
                  size: 13, color: AppColors.mute)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(pct),
          child: Text('common.save'.tr(),
              style: AppTypography.label(
                  size: 13, color: AppColors.amber)),
        ),
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.challenge,
    required this.onJoin,
    required this.onUpdateProgress,
    this.progress,
  });

  final Challenge challenge;
  final ChallengeProgress? progress;
  final VoidCallback onJoin;
  final VoidCallback onUpdateProgress;

  @override
  Widget build(BuildContext context) {
    // BUGFIX: progress_pct ist BEREITS ein Prozentwert (0..100) — vorher
    // wurde er durch max_participants (Teilnehmer-Limit, ohne Bezug zum
    // Fortschritt) geteilt → Balken fast immer voll oder völlig falsch
    // (bei max_participants=null sogar immer 100%). Jetzt direkt pct/100.
    final pct = (progress?.progressPct ?? 0).clamp(0, 100);
    final ratio = pct / 100.0;
    final completed = progress?.completed ?? false;
    final isJoined = progress != null;

    final canUpdate = isJoined && !completed;

    return GestureDetector(
      onTap: canUpdate ? onUpdateProgress : null,
      child: Container(
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
                child: Text(
                    challenge.category != null
                        ? _localizedCategory(challenge.category)
                        : _localizedDifficulty(challenge.difficulty),
                    style: AppTypography.label(size: 9)),
              ),
              const Spacer(),
              if (challenge.points != null)
                Text('+${challenge.points} P',
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
                '$pct%',
                style: AppTypography.mono(
                  size: 11,
                  color: AppColors.inkSoft,
                ),
              ),
              const Spacer(),
              if (completed)
                Text('challenges.done'.tr(),
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
                )
              else
                TextButton(
                  onPressed: onUpdateProgress,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 28),
                    backgroundColor:
                        AppColors.amber.withValues(alpha: 0.10),
                  ),
                  child: Text('challenges.updateProgress'.tr(),
                      style: AppTypography.label(
                        size: 10,
                        color: AppColors.amber,
                      )),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
