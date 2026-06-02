/// SKILL: mensaena-features + mensaena-design
/// Mood-Check-In-Dialog — 5 Emoji-Buttons + optionale Notiz.
/// Bei negativem Streak (3 Tage mood ≤2) → Hinweis auf Telefonseelsorge.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/mood_repository.dart';
import '../../services/haptics.dart';
import '../../utils/safe_launch.dart';

class MoodCheckInDialog extends StatefulWidget {
  const MoodCheckInDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const MoodCheckInDialog(),
    );
  }

  @override
  State<MoodCheckInDialog> createState() => _MoodCheckInDialogState();
}

class _MoodCheckInDialogState extends State<MoodCheckInDialog> {
  int? _selected;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);
    Haptics.confirm();
    final entry = await MoodRepository.log(
      level: _selected!,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('mood.saveFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      setState(() => _saving = false);
      return;
    }
    final negStreak = await MoodRepository.hasNegativeStreak();
    if (!mounted) return;
    final shouldShowHelp = negStreak && _selected! <= 2;
    final navigator = Navigator.of(context);
    final overlayContext = navigator.overlay?.context;
    navigator.pop(true);
    if (shouldShowHelp && overlayContext != null && overlayContext.mounted) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (overlayContext.mounted) _showHelpHint(overlayContext);
      });
    }
  }

  static const List<String> _emojis = ['😢', '😟', '😐', '🙂', '😄'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('mood.title'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('mood.howAreYou'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final level = i + 1;
                final selected = _selected == level;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Haptics.tap();
                    setState(() => _selected = level);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.bronze.withValues(alpha: 0.22)
                          : AppColors.elevated,
                      border: Border.all(
                        color: selected
                            ? AppColors.bronze
                            : AppColors.line,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      _emojis[i],
                      style: TextStyle(fontSize: selected ? 30 : 24),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'mood.note'.tr(),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: AppTypography.body(size: 13, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text('common.skip'.tr()),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      (_selected == null || _saving) ? null : _save,
                  icon: const Icon(LucideIcons.heart, size: 14),
                  label: Text('mood.save'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpHint(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.heart,
                size: 20, color: AppColors.herzrot),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'mood.helpTitle'.tr(),
                style: AppTypography.body(
                    size: 15, color: AppColors.ink, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'mood.helpHint'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.close'.tr()),
          ),
          FilledButton.icon(
            onPressed: () async {
              await safeLaunch('tel:08001110111');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(LucideIcons.phone, size: 14),
            label: Text('mood.callTelefonseelsorge'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.herzrot,
            ),
          ),
        ],
      ),
    );
  }
}
