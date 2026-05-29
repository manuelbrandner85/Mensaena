/// SKILL: mensaena-features (F72)
/// Community-Polls — Liste aktiver Umfragen, Voting, Live-Ergebnisse.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/mega_models.dart';
import '../../providers/mega_providers.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/haptics.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class CommunityPollsScreen extends ConsumerWidget {
  const CommunityPollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeCommunityPollsProvider);
    return DashboardScaffold(
      title: 'community.polls'.tr(),
      currentRoute: '/dashboard/community-polls',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(LucideIcons.plus),
        label: Text('community.create_poll'.tr()),
      ),
      onRefresh: () async {
        ref.invalidate(activeCommunityPollsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (polls) {
          if (polls.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.barChart3,
                        size: 32, color: AppColors.mute),
                    const SizedBox(height: 8),
                    Text('community.no_polls'.tr(),
                        style: AppTypography.caption()),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: polls.length,
            itemBuilder: (_, i) => _PollCard(poll: polls[i]),
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final qCtrl = TextEditingController();
    final opts = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    bool anon = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 22,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('community.create_poll'.tr(),
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qCtrl,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'community.question'.tr(),
                      filled: true,
                      fillColor: AppColors.elevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < opts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: TextField(
                        controller: opts[i],
                        decoration: InputDecoration(
                          labelText:
                              '${'community.option'.tr()} ${i + 1}',
                          filled: true,
                          fillColor: AppColors.elevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  if (opts.length < 6)
                    TextButton.icon(
                      onPressed: () => setState(
                          () => opts.add(TextEditingController())),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: Text('community.add_option'.tr()),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: anon,
                    onChanged: (v) => setState(() => anon = v),
                    title: Text('community.anonymous'.tr()),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final options = opts
                            .map((c) => c.text.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        if (qCtrl.text.trim().isEmpty ||
                            options.length < 2) {
                          return;
                        }
                        final ok = await CommunityPollsRepository.create(
                          question: qCtrl.text.trim(),
                          options: options,
                          isAnonymous: anon,
                        );
                        if (ok) {
                          ref.invalidate(activeCommunityPollsProvider);
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bronze,
                        foregroundColor: AppColors.voidColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('community.publish'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    qCtrl.dispose();
    for (final c in opts) {
      c.dispose();
    }
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.poll});
  final CommunityPoll poll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(pollVoteCountsProvider(poll.id));
    final myVoteAsync = ref.watch(myPollVoteProvider(poll.id));
    final counts = countsAsync.valueOrNull ?? {};
    final myVote = myVoteAsync.valueOrNull;
    final totalVotes = counts.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.question,
                style: AppTypography.display(
                    size: 16, color: AppColors.ink)),
            if (poll.creatorName != null) ...[
              const SizedBox(height: 4),
              Text(
                  '${poll.isAnonymous ? '👤' : ''} ${poll.creatorName ?? ''}'
                      .trim(),
                  style: AppTypography.caption()),
            ],
            const SizedBox(height: 12),
            for (int i = 0; i < poll.options.length; i++)
              _OptionBar(
                label: poll.options[i],
                count: counts[i] ?? 0,
                total: totalVotes,
                voted: myVote == i,
                disabled: myVote != null || poll.isClosed,
                onTap: () async {
                  if (myVote != null || poll.isClosed) return;
                  Haptics.confirm();
                  final ok =
                      await CommunityPollsRepository.vote(poll.id, i);
                  if (ok) {
                    ref.invalidate(pollVoteCountsProvider(poll.id));
                    ref.invalidate(myPollVoteProvider(poll.id));
                  }
                },
              ),
            const SizedBox(height: 6),
            Text(
              '$totalVotes ${'community.votes'.tr()}',
              style: AppTypography.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.voted,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final int count;
  final int total;
  final bool voted;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // Visuelles Feedback: bereits abgestimmte/gesperrte Optionen leicht
      // ausgrauen, damit klar ist warum kein Tap reagiert.
      child: Opacity(
        opacity: disabled && !voted ? 0.45 : 1.0,
        child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: voted
                      ? AppColors.bronze
                      : AppColors.line,
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: voted
                      ? AppColors.bronze.withValues(alpha: 0.45)
                      : AppColors.bronze.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (voted)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(LucideIcons.check,
                          size: 14, color: AppColors.bronze),
                    ),
                  Expanded(
                    child: Text(label,
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: voted
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                  Text(total > 0 ? '${(pct * 100).round()}%' : '0%',
                      style: AppTypography.body(
                          size: 11,
                          color: AppColors.mute,
                          weight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
