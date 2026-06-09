/// SKILL: mensaena-features (P7) — Inline-Poll im Post-Feed/Detail.
/// Lädt post_polls + post_poll_votes für postId, zeigt Optionen mit
/// Live-Bars, lässt eigenen Vote setzen/ändern.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class PollData {
  const PollData({
    required this.pollId,
    required this.question,
    required this.options,
    required this.votesByOption,
    required this.myVote,
    required this.closesAt,
  });
  final String pollId;
  final String question;
  final List<String> options;
  final List<int> votesByOption;
  final int? myVote;
  final DateTime? closesAt;

  int get total => votesByOption.fold<int>(0, (a, b) => a + b);
  bool get isClosed =>
      closesAt != null && closesAt!.isBefore(DateTime.now());
}

final postPollProvider =
    FutureProvider.autoDispose.family<PollData?, String>((ref, postId) async {
  try {
    final pollRow = await sb
        .from('post_polls')
        .select()
        .eq('post_id', postId)
        .maybeSingle();
    if (pollRow == null) return null;
    final pollId = pollRow['id'] as String;
    final opts = (pollRow['options'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];
    final votes = await sb
        .from('post_poll_votes')
        .select('user_id, option_index')
        .eq('poll_id', pollId);
    final counts = List<int>.filled(opts.length, 0);
    int? mine;
    final myId = SupabaseService.currentUser?.id;
    for (final v in (votes as List).whereType<Map<String, dynamic>>()) {
      final idx = (v['option_index'] as num?)?.toInt() ?? -1;
      if (idx >= 0 && idx < counts.length) {
        counts[idx] += 1;
        if (v['user_id'] == myId) mine = idx;
      }
    }
    return PollData(
      pollId: pollId,
      question: pollRow['question'] as String? ?? '',
      options: opts,
      votesByOption: counts,
      myVote: mine,
      closesAt: pollRow['closes_at'] != null
          ? DateTime.tryParse(pollRow['closes_at'] as String)?.toUtc()
          : null,
    );
  } catch (_) {
    return null;
  }
});

class PostPollWidget extends ConsumerWidget {
  const PostPollWidget({required this.postId, super.key});
  final String postId;

  Future<void> _vote(WidgetRef ref, PollData poll, int idx) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || poll.isClosed) return;
    try {
      if (poll.myVote == null) {
        await sb.from('post_poll_votes').insert({
          'poll_id': poll.pollId,
          'user_id': uid,
          'option_index': idx,
        });
      } else {
        await sb
            .from('post_poll_votes')
            .update({'option_index': idx})
            .eq('poll_id', poll.pollId)
            .eq('user_id', uid);
      }
      ref.invalidate(postPollProvider(postId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(postPollProvider(postId)).maybeWhen(
          data: (poll) {
            if (poll == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poll.question,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (int i = 0; i < poll.options.length; i++) ...[
                    _Option(
                      label: poll.options[i],
                      count: poll.votesByOption[i],
                      total: poll.total,
                      mine: poll.myVote == i,
                      disabled: poll.isClosed,
                      onTap: () => _vote(ref, poll, i),
                    ),
                    if (i < poll.options.length - 1)
                      const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    poll.isClosed
                        ? 'polls.closed'
                            .tr(namedArgs: {'n': '${poll.total}'})
                        : 'polls.total_votes'
                            .tr(namedArgs: {'n': '${poll.total}'}),
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.count,
    required this.total,
    required this.mine,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final int count;
  final int total;
  final bool mine;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    color: mine
                        ? AppColors.bronze.withValues(alpha: 0.32)
                        : AppColors.amber.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: mine ? FontWeight.w700 : FontWeight.w500)),
                ),
                Text('${(pct * 100).round()} %',
                    style: AppTypography.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
