/// SKILL: mensaena-features (UX-Welle1 D2)
/// "Themen folgen"-Screen — User folgt Tags, um Feed zu kuratieren.
/// Liste der eigenen gefolgten Tags + Add/Remove. Vorschlagsleiste
/// mit Top-Tags aus post_tags.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/extra_repositories.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

final _myFollowedTagsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return FollowedTagsRepository.myTags();
});

final _suggestedTagsProvider =
    FutureProvider.autoDispose<List<({String tag, int count})>>(
        (ref) async {
  try {
    final rows = await sb
        .from('post_tags')
        .select('tag')
        .limit(500);
    final counts = <String, int>{};
    for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
      final t = (r['tag'] as String?)?.trim().toLowerCase();
      if (t == null || t.isEmpty) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(20)
        .map((e) => (tag: e.key, count: e.value))
        .toList();
  } catch (_) {
    return const [];
  }
});

class FollowedTagsScreen extends ConsumerStatefulWidget {
  const FollowedTagsScreen({super.key});

  @override
  ConsumerState<FollowedTagsScreen> createState() =>
      _FollowedTagsScreenState();
}

class _FollowedTagsScreenState extends ConsumerState<FollowedTagsScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(String raw) async {
    final t = raw.trim().toLowerCase().replaceAll('#', '');
    if (t.isEmpty) return;
    Haptics.tap();
    final added = await FollowedTagsRepository.toggleFollow(t);
    if (!mounted) return;
    if (added) _input.clear();
    ref.invalidate(_myFollowedTagsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        added
            ? 'followed_tags.added'.tr(namedArgs: {'tag': t})
            : 'followed_tags.removed'.tr(namedArgs: {'tag': t}),
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(_myFollowedTagsProvider);
    final suggested = ref.watch(_suggestedTagsProvider);
    return DashboardScaffold(
      title: 'followed_tags.title'.tr(),
      currentRoute: '/dashboard/followed-tags',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'followed_tags.intro'.tr(),
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: _add,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'followed_tags.addHint'.tr(),
                      hintStyle: AppTypography.caption(),
                      prefixIcon: const Icon(LucideIcons.hash,
                          size: 16, color: AppColors.mute),
                      filled: true,
                      fillColor: AppColors.elevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _add(_input.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Icon(LucideIcons.plus, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('followed_tags.mine'.tr().toUpperCase(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            mine.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.bronze)),
              ),
              error: (e, _) => Text('$e', style: AppTypography.caption()),
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'followed_tags.empty'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute),
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      InputChip(
                        label: Text('#$t',
                            style: AppTypography.body(
                                size: 12,
                                color: AppColors.ink,
                                weight: FontWeight.w600)),
                        backgroundColor:
                            AppColors.amber.withValues(alpha: 0.18),
                        side: BorderSide(
                            color: AppColors.amber.withValues(alpha: 0.5)),
                        deleteIcon: const Icon(LucideIcons.x, size: 14),
                        onDeleted: () => _add(t),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text('followed_tags.suggested'.tr().toUpperCase(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            suggested.when(
              loading: () => const SizedBox(height: 60),
              error: (e, _) => Text('$e', style: AppTypography.caption()),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'followed_tags.noSuggestions'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.mute),
                  );
                }
                final myList = mine.value ?? const <String>[];
                final pool = list.where((e) => !myList.contains(e.tag));
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in pool)
                      ActionChip(
                        label: Text(
                          '#${s.tag} · ${s.count}',
                          style: AppTypography.body(
                              size: 11, color: AppColors.bronze),
                        ),
                        backgroundColor: AppColors.surface
                            .withValues(alpha: 0.55),
                        side: BorderSide(
                            color: AppColors.bronze.withValues(alpha: 0.4)),
                        onPressed: () => _add(s.tag),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
