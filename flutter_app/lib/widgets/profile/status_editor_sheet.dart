/// SKILL: mensaena-features (P10) — Custom Status-Text.
/// User wählt Emoji + Text, gilt bis manuelle Löschung oder
/// optional bis Ablaufzeit (4h/24h/Woche).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';

final myStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ProfilesRepository.myStatus();
});

class StatusEditorSheet extends ConsumerStatefulWidget {
  const StatusEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const StatusEditorSheet(),
    );
  }

  @override
  ConsumerState<StatusEditorSheet> createState() => _StatusEditorSheetState();
}

class _StatusEditorSheetState extends ConsumerState<StatusEditorSheet> {
  final _ctrl = TextEditingController();
  String _emoji = '💬';
  Duration? _duration;
  bool _saving = false;

  static const _emojis = ['💬', '☕', '📚', '🌱', '🏃', '🏡', '😊', '💤', '✈️'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final cur = await ref.read(myStatusProvider.future);
      if (!mounted || cur == null) return;
      setState(() {
        _ctrl.text = (cur['status_text'] as String?) ?? '';
        _emoji = (cur['status_emoji'] as String?) ?? '💬';
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _saving = true);
    final until = _duration == null
        ? null
        : DateTime.now().add(_duration!).toIso8601String();
    final empty = _ctrl.text.trim().isEmpty;
    try {
      await ProfilesRepository.update(uid, {
        'status_text': empty ? null : _ctrl.text.trim(),
        'status_emoji': empty ? null : _emoji,
        'status_until': until,
      });
      ref.invalidate(myStatusProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ProfilesRepository.update(uid, {
        'status_text': null,
        'status_emoji': null,
        'status_until': null,
      });
      ref.invalidate(myStatusProvider);
      if (mounted) Navigator.pop(context);
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
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.messageSquare,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('status.title'.tr(),
                  style: AppTypography.display(size: 18, color: AppColors.ink)),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _emojis
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? AppColors.bronze.withValues(alpha: 0.22)
                                : AppColors.elevated,
                            border: Border.all(
                                color: _emoji == e
                                    ? AppColors.bronze
                                    : AppColors.line),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Text(e, style: const TextStyle(fontSize: 20)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'status.hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final d in [
                null,
                const Duration(hours: 4),
                const Duration(hours: 24),
                const Duration(days: 7),
              ])
                ChoiceChip(
                  selected: _duration == d,
                  label: Text(d == null
                      ? 'status.until_cleared'.tr()
                      : d.inHours < 24
                          ? 'status.duration_hours'
                              .tr(namedArgs: {'n': '${d.inHours}'})
                          : 'status.duration_days'
                              .tr(namedArgs: {'n': '${d.inDays}'})),
                  onSelected: (_) => setState(() => _duration = d),
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _clear,
                  icon: const Icon(LucideIcons.x, size: 14),
                  label: Text('status.clear'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(LucideIcons.check, size: 14),
                  label: Text('common.save'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
