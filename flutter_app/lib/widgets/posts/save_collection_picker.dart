/// SKILL: mensaena-features (P7) — Save-Collections-Picker.
/// Sheet zum Anlegen + Wählen einer Sammlung beim Save.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

final saveCollectionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const [];
  try {
    final rows = await sb
        .from('save_collections')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  }
});

class SaveCollectionPicker {
  /// Liefert die gewählte collection_id oder null (= 'Allgemein'/keine Sammlung).
  /// Gibt 'CANCEL' zurück bei Cancel.
  static Future<({bool cancelled, String? id})> pick(
      BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({bool cancelled, String? id})>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PickerSheet(),
    );
    return result ?? (cancelled: true, id: null);
  }
}

class _PickerSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('collections.create_title'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: 'collections.name'.tr(),
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emojiCtrl,
            maxLength: 4,
            decoration: InputDecoration(
                labelText: 'collections.emoji'.tr(),
                border: const OutlineInputBorder(),
                counterText: ''),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.bronze),
            child: Text('common.create'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('save_collections').insert({
        'user_id': uid,
        'name': nameCtrl.text.trim(),
        'emoji': emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
      });
      ref.invalidate(saveCollectionsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(saveCollectionsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.folder,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('collections.pick_title'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
              const Spacer(),
              IconButton(
                onPressed: _create,
                icon: const Icon(LucideIcons.plus, size: 18),
                tooltip: 'collections.new'.tr(),
              ),
            ]),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.bookmark,
                  color: AppColors.bronze),
              title: Text('collections.default'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600)),
              onTap: () =>
                  Navigator.pop(context, (cancelled: false, id: null)),
            ),
            const Divider(color: AppColors.line),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.bronze)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('collections.empty'.tr(),
                            style: AppTypography.caption()),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final emoji = c['emoji'] as String? ?? '📁';
                          final name = c['name'] as String? ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Text(emoji,
                                style: const TextStyle(fontSize: 20)),
                            title: Text(name,
                                style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.ink,
                                    weight: FontWeight.w600)),
                            onTap: () => Navigator.pop(context,
                                (cancelled: false, id: c['id'] as String)),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
