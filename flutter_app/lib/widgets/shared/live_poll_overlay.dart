/// SKILL: mensaena-features + mensaena-design
/// LivePollOverlay — Host startet Umfrage, Zuschauer sehen Echtzeit-
/// Stimmen-Anteile. State wird via RoomEventsService (Data-Channel)
/// synchronisiert. Keine DB noetig — Poll lebt nur waehrend Stream.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class LivePoll {
  LivePoll({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<String> options;
  // Map<optionIndex, Set<voterIdentity>> — verhindert Doppel-Vote.
  final Map<int, Set<String>> votes = {};

  int votesFor(int index) => votes[index]?.length ?? 0;

  int get totalVotes =>
      votes.values.fold<int>(0, (sum, s) => sum + s.length);
}

class LivePollOverlay extends StatelessWidget {
  const LivePollOverlay({
    required this.poll,
    required this.onVote,
    required this.onClose,
    required this.isHost,
    required this.myIdentity,
    super.key,
  });

  final LivePoll poll;
  final void Function(int optionIndex) onVote;
  final VoidCallback onClose;
  final bool isHost;
  final String myIdentity;

  @override
  Widget build(BuildContext context) {
    final myVote = poll.votes.entries
        .firstWhere((e) => e.value.contains(myIdentity),
            orElse: () => const MapEntry(-1, <String>{}))
        .key;
    final total = poll.totalVotes;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.barChart3,
                  size: 16, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: AppTypography.body(
                      size: 14,
                      color: Colors.white,
                      weight: FontWeight.w700),
                ),
              ),
              if (isHost)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(LucideIcons.x,
                      size: 16, color: Colors.white70),
                  splashRadius: 14,
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < poll.options.length; i++)
            _PollOption(
              index: i,
              label: poll.options[i],
              voteCount: poll.votesFor(i),
              totalVotes: total,
              isSelected: myVote == i,
              onTap: () => onVote(i),
            ),
          const SizedBox(height: 4),
          Text(
            'livePoll.totalVotes'.tr(namedArgs: {'n': '$total'}),
            style: AppTypography.caption(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.index,
    required this.label,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final String label;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes == 0 ? 0.0 : voteCount / totalVotes;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.bronze
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Stack(
          children: [
            // Stimmen-Bar (Hintergrund)
            FractionallySizedBox(
              widthFactor: pct.clamp(0.02, 1.0),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.bronze.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body(
                          size: 13,
                          color: Colors.white,
                          weight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400),
                    ),
                  ),
                  Text(
                    '$voteCount (${(pct * 100).toStringAsFixed(0)}%)',
                    style: AppTypography.mono(
                        size: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host-Modal: erzeugt einen neuen Poll. Question + bis zu 4 Optionen.
class CreatePollSheet extends StatefulWidget {
  const CreatePollSheet({super.key});

  static Future<LivePoll?> show(BuildContext context) {
    return showModalBottomSheet<LivePoll?>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const CreatePollSheet(),
      ),
    );
  }

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _qCtrl = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _start(BuildContext context) {
    final q = _qCtrl.text.trim();
    final opts = _options
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (q.isEmpty || opts.length < 2) return;
    final poll = LivePoll(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      question: q,
      options: opts,
    );
    Navigator.of(context).pop(poll);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('livePoll.create'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _qCtrl,
              maxLength: 100,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'livePoll.questionHint'.tr(),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: AppTypography.body(size: 14, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  controller: _options[i],
                  maxLength: 40,
                  decoration: InputDecoration(
                    hintText: 'livePoll.option'.tr(
                        namedArgs: {'n': '${i + 1}'}),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.elevated,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style:
                      AppTypography.body(size: 13, color: AppColors.ink),
                ),
              ),
            if (_options.length < 4)
              TextButton.icon(
                onPressed: () => setState(
                    () => _options.add(TextEditingController())),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text('livePoll.addOption'.tr()),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.bronze),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _start(context),
                icon: const Icon(LucideIcons.barChart3, size: 16),
                label: Text('livePoll.start'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
