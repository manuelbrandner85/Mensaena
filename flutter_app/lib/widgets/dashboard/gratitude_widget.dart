/// SKILL: mensaena-features + mensaena-design
/// Gratitude-Widget (F30): zeigt heutigen Dankbarkeitseintrag oder Prompt
/// zum Schreiben. Tap → Bottom-Sheet mit TextField.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/gratitude_service.dart';
import '../../services/haptics.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';
import 'tile_error.dart';

final _gratitudeTodayProvider =
    FutureProvider.autoDispose<GratitudeEntry?>((ref) async {
  return GratitudeService.today();
});

class GratitudeWidget extends ConsumerWidget {
  const GratitudeWidget({super.key});

  Future<void> _openSheet(BuildContext context, WidgetRef ref,
      {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                const Icon(LucideIcons.heart,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('gratitude.sheetTitle'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 8),
            Text('gratitude.sheetHint'.tr(),
                style: AppTypography.body(
                    size: 12,
                    color: AppColors.inkSoft,
                    height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              maxLength: 280,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'gratitude.placeholder'.tr(),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                icon: const Icon(LucideIcons.check, size: 16),
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
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      Haptics.success();
      await GratitudeService.setToday(result);
      ref.invalidate(_gratitudeTodayProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_gratitudeTodayProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: async.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.bronze),
            ),
          ),
        ),
        error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(_gratitudeTodayProvider)),
        data: (entry) {
          final hasEntry = entry != null;
          return InkWell(
            onTap: () => _openSheet(context, ref, initial: entry?.text),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Bloom(
                    color: AppColors.herzrotWarm,
                    intensity: 0.4,
                    radius: 10,
                    child: Icon(LucideIcons.heart,
                        size: 20, color: AppColors.herzrotWarm),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('gratitude.title'.tr(),
                            style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          hasEntry ? entry.text : 'gratitude.prompt'.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 12,
                            color: hasEntry
                                ? AppColors.inkSoft
                                : AppColors.mute,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasEntry ? LucideIcons.edit2 : LucideIcons.plus,
                    size: 16,
                    color: AppColors.bronze,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
