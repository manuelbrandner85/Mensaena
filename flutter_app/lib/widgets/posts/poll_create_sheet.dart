/// SKILL: mensaena-features (P7) — Poll an Post anhängen.
/// Owner kann eine Abstimmung mit Frage + 2-6 Optionen + optional
/// Close-Date erstellen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class PollCreateSheet extends ConsumerStatefulWidget {
  const PollCreateSheet({required this.postId, super.key});
  final String postId;

  static Future<bool?> show(BuildContext context, {required String postId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PollCreateSheet(postId: postId),
    );
  }

  @override
  ConsumerState<PollCreateSheet> createState() => _PollCreateSheetState();
}

class _PollCreateSheetState extends ConsumerState<PollCreateSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _opts = [
    TextEditingController(),
    TextEditingController(),
  ];
  Duration? _closesIn;
  bool _saving = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_opts.length >= 6) return;
    setState(() => _opts.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_opts.length <= 2) return;
    setState(() {
      _opts[i].dispose();
      _opts.removeAt(i);
    });
  }

  Future<void> _save() async {
    final q = _questionCtrl.text.trim();
    final options =
        _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (q.isEmpty || options.length < 2) return;
    setState(() => _saving = true);
    try {
      await sb.from('post_polls').insert({
        'post_id': widget.postId,
        'question': q,
        'options': options,
        'closes_at': _closesIn == null
            ? null
            : DateTime.now().add(_closesIn!).toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.barChart3,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('polls.create_title'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _questionCtrl,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'polls.question'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _opts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _opts[i],
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText:
                            'polls.option_n'.tr(namedArgs: {'n': '${i + 1}'}),
                        border: const OutlineInputBorder(),
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_opts.length > 2)
                    IconButton(
                      onPressed: () => _removeOption(i),
                      icon: const Icon(LucideIcons.minus, size: 16),
                    ),
                ]),
              ),
            if (_opts.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text('polls.add_option'.tr()),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final d in [
                null,
                const Duration(hours: 24),
                const Duration(days: 3),
                const Duration(days: 7),
              ])
                ChoiceChip(
                  selected: _closesIn == d,
                  label: Text(d == null
                      ? 'polls.no_close'.tr()
                      : d.inDays < 1
                          ? 'polls.duration_hours'
                              .tr(namedArgs: {'n': '${d.inHours}'})
                          : 'polls.duration_days'
                              .tr(namedArgs: {'n': '${d.inDays}'})),
                  onSelected: (_) => setState(() => _closesIn = d),
                ),
            ]),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.check, size: 14),
              label: Text('common.save'.tr()),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ),
      ),
    );
  }
}
