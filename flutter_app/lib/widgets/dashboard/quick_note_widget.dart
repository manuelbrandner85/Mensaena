/// SKILL: mensaena-features + mensaena-design
/// Quick-Note-Widget (F45): on-device Sticky-Note. Tap → Editor-Sheet.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';
import '../../services/quick_note_service.dart';
import '../effects/glass_card.dart';
import 'tile_error.dart';

final _quickNoteProvider =
    FutureProvider.autoDispose<String>((ref) async {
  return QuickNoteService.read();
});

class QuickNoteWidget extends ConsumerWidget {
  const QuickNoteWidget({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 22,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.stickyNote,
                      size: 18, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Text('quickNote.sheetTitle'.tr(),
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 4,
                autofocus: true,
                maxLength: 1000,
                style:
                    AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'quickNote.placeholder'.tr(),
                  hintStyle: AppTypography.body(
                      size: 14, color: AppColors.mute),
                  filled: true,
                  fillColor: AppColors.elevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(''),
                      icon: const Icon(LucideIcons.trash2, size: 14),
                      label: Text('quickNote.clear'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.herzrotWarm,
                        side: BorderSide(
                            color: AppColors.herzrotWarm
                                .withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text),
                      icon: const Icon(LucideIcons.check, size: 14),
                      label: Text('common.save'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bronze,
                        foregroundColor: AppColors.voidColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      Haptics.tap();
      await QuickNoteService.write(result);
      ref.invalidate(_quickNoteProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_quickNoteProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(_quickNoteProvider)),
      data: (note) {
        final empty = note.trim().isEmpty;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: InkWell(
            onTap: () => _openEditor(context, ref, note),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(LucideIcons.stickyNote,
                        size: 18, color: AppColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('quickNote.title'.tr(),
                            style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          empty ? 'quickNote.prompt'.tr() : note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 12,
                            color: empty
                                ? AppColors.mute
                                : AppColors.inkSoft,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    empty ? LucideIcons.plus : LucideIcons.edit2,
                    size: 16,
                    color: AppColors.bronze,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
