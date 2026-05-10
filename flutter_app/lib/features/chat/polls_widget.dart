import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'polls_repository.dart';

/// Bottom-Sheet zum Erstellen einer neuen Umfrage in einem Channel.
/// Pendant zur Web-CreatePoll-Logic in ChatView.tsx.
class CreatePollSheet extends ConsumerStatefulWidget {
  const CreatePollSheet({super.key, required this.channelId});
  final String channelId;

  static Future<ChannelPoll?> show(
    BuildContext context, {
    required String channelId,
  }) {
    return showModalBottomSheet<ChannelPoll>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreatePollSheet(channelId: channelId),
    );
  }

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  final _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  Duration? _duration;
  bool _saving = false;

  static const _durationOptions = <(Duration?, String)>[
    (null, 'Offen'),
    (Duration(hours: 1), '1 Stunde'),
    (Duration(hours: 24), '1 Tag'),
    (Duration(days: 7), '1 Woche'),
  ];

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() {
      _options.removeAt(index).dispose();
    });
  }

  bool get _canSubmit {
    if (_question.text.trim().isEmpty) return false;
    final filled = _options.where((c) => c.text.trim().isNotEmpty).length;
    return filled >= 2;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final poll = await ref.read(pollsRepositoryProvider).create(
            channelId: widget.channelId,
            question: _question.text.trim(),
            options: _options.map((c) => c.text).toList(),
            endsAt: _duration == null ? null : DateTime.now().add(_duration!),
          );
      if (!mounted) return;
      Navigator.of(context).pop(poll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.stone200,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Umfrage erstellen',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Frage *',
                hintText: 'Worüber soll abgestimmt werden?',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            ..._options.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: 'Option ${e.key + 1}',
                          hintText: 'Antwort-Möglichkeit',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_options.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeOption(e.key),
                      ),
                  ],
                ),
              ),
            ),
            if (_options.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Option hinzufügen'),
                  onPressed: _addOption,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Dauer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink400,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _durationOptions
                  .map(
                    (opt) => ChoiceChip(
                      label: Text(opt.$2),
                      selected: _duration == opt.$1,
                      onSelected: (_) => setState(() => _duration = opt.$1),
                      selectedColor:
                          AppColors.primary500.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (_canSubmit && !_saving) ? _submit : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.poll_outlined),
              label: Text(_saving ? 'Erstelle…' : 'Umfrage starten'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card-Widget pro Umfrage. Zeigt Frage, Optionen mit Stimmen-Balken,
/// erlaubt Vote oder Vote-Zurücknahme.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key, required this.poll});
  final ChannelPoll poll;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  Map<int, List<String>> _votes = const {};
  bool _loading = true;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _loadVotes();
  }

  Future<void> _loadVotes() async {
    try {
      final m = await ref
          .read(pollsRepositoryProvider)
          .votesFor(widget.poll.id);
      if (!mounted) return;
      setState(() {
        _votes = m;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(int? optionIndex) async {
    if (_voting) return;
    setState(() => _voting = true);
    HapticFeedback.lightImpact();
    try {
      await ref.read(pollsRepositoryProvider).vote(
            pollId: widget.poll.id,
            optionIndex: optionIndex,
          );
      await _loadVotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  int? _myVote(String? myUserId) {
    if (myUserId == null) return null;
    for (final entry in _votes.entries) {
      if (entry.value.contains(myUserId)) return entry.key;
    }
    return null;
  }

  String _endsLabel() {
    final ends = widget.poll.endsAt;
    if (ends == null) return 'Offen';
    if (DateTime.now().isAfter(ends)) {
      return 'Beendet ${DateFormat('d. MMM HH:mm', 'de').format(ends)}';
    }
    final remaining = ends.difference(DateTime.now());
    if (remaining.inDays >= 1) return 'Endet in ${remaining.inDays} Tagen';
    if (remaining.inHours >= 1) {
      return 'Endet in ${remaining.inHours} Std.';
    }
    return 'Endet in ${remaining.inMinutes} Min.';
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(supabaseProvider).auth.currentUser?.id;
    final myVote = _myVote(myId);
    final totalVotes =
        _votes.values.fold<int>(0, (sum, list) => sum + list.length);
    final isExpired = widget.poll.isExpired;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary500.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined,
                  size: 16, color: AppColors.primary500),
              const SizedBox(width: 6),
              const Text(
                'Umfrage',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                _endsLabel(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.ink400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.poll.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            ...List.generate(widget.poll.options.length, (i) {
              final option = widget.poll.options[i];
              final count = _votes[i]?.length ?? 0;
              final pct = totalVotes == 0 ? 0.0 : count / totalVotes;
              final isMine = myVote == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: (isExpired || _voting)
                      ? null
                      : () => _vote(isMine ? null : i),
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.stone100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: isMine
                                ? AppColors.primary500.withValues(alpha: 0.3)
                                : AppColors.primary500.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,),
                        child: Row(
                          children: [
                            if (isMine)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AppColors.primary500,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontWeight: isMine
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).round()}% · $count',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 6),
          Text(
            '$totalVotes Stimme${totalVotes == 1 ? '' : 'n'}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.ink400,
            ),
          ),
        ],
      ),
    );
  }
}
