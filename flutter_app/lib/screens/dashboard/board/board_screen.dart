import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/board_post.dart';
import '../../../repositories/board_repository.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/skeleton_card.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features
/// Schwarzes Brett — 1:1 zu `src/app/dashboard/board/page.tsx`.
/// Search-Bar + Kategorie-Filter (9) + Aktive-Filter-Strip + Grid + FAB.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  // Mirror von CATEGORY_LABELS + CATEGORY_ICONS aus useBoard.ts.
  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'general', label: '📌 Allgemein'),
    FilterOption(value: 'gesucht', label: '🔍 Gesucht'),
    FilterOption(value: 'biete', label: '🎁 Biete'),
    FilterOption(value: 'event', label: '📅 Event'),
    FilterOption(value: 'info', label: 'ℹ️ Info'),
    FilterOption(value: 'warnung', label: '⚠️ Warnung'),
    FilterOption(value: 'verloren', label: '😢 Verloren'),
    FilterOption(value: 'fundbuero', label: '🔑 Fundbüro'),
  ];

  String _search = '';
  String _category = 'all';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _search = v);
    });
  }

  List<BoardPost> _apply(List<BoardPost> all) {
    final q = _search.trim().toLowerCase();
    return all.where((p) {
      if (_category != 'all' && p.category != _category) return false;
      if (q.isEmpty) return true;
      return p.content.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(boardPostsProvider);
    final hasFilters = _search.isNotEmpty || _category != 'all';

    return DashboardScaffold(
      title: 'board.screenTitle'.tr(),
      currentRoute: '/dashboard/board',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/board/create'),
        icon: const Icon(LucideIcons.stickyNote),
        label: Text('board.pin'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 06',
                metaCategory: 'board.screenTitle'.tr(),
                title: 'modules.board.titleAlt'.tr(),
                subtitle: 'modules.board.subtitle'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: ModuleSearchBar(
                hintText: 'board.searchPlaceholder'.tr(),
                onChanged: _onSearch,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: FilterChipBar<String>(
                options: _categories,
                selected: _category == 'all' ? const <String>{} : {_category},
                onChanged: (s) =>
                    setState(() => _category = s.isEmpty ? 'all' : s.first),
              ),
            ),
            if (hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_category != 'all')
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _category,
                                orElse: () => _categories.first)
                            .label,
                        onRemove: () => setState(() => _category = 'all'),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _search = '';
                    _category = 'all';
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.invalidate(boardPostsProvider),
                child: async.when(
                  loading: () => const SkeletonList(count: 5, itemHeight: 96),
                  error: (e, _) => Center(
                    child: ErrorStateWidget(
                      onRetry: () => ref.invalidate(boardPostsProvider),
                    ),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.stickyNote,
                            title: hasFilters
                                ? 'Keine Treffer.'
                                : 'Pinnwand ist leer.',
                            description: hasFilters
                                ? 'Andere Filter probieren.'
                                : 'Sei der/die Erste:r — Plus-Button.',
                            actionLabel:
                                hasFilters ? 'Filter zurücksetzen' : null,
                            onAction: hasFilters
                                ? () => setState(() {
                                      _search = '';
                                      _category = 'all';
                                    })
                                : null,
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => AnimatedEntrance(
                        index: i,
                        child: _Note(post: list[i]),
                      ),
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

class _Note extends StatelessWidget {
  const _Note({required this.post});
  final BoardPost post;

  static const Map<String, Color> _bgColors = {
    'yellow': Color(0xFFFEF08A),
    'green': Color(0xFFBBF7D0),
    'blue': Color(0xFFBFDBFE),
    'pink': Color(0xFFFBCFE8),
    'orange': Color(0xFFFED7AA),
    'purple': Color(0xFFE9D5FF),
  };

  @override
  Widget build(BuildContext context) {
    final base = _bgColors[post.color] ?? const Color(0xFFFEF08A);
    return InkWell(
      onTap: () => context.push('/dashboard/board/${post.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.12),
          border: Border.all(color: base.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(LucideIcons.pin,
                        size: 11, color: AppColors.amber),
                  ),
                Text(
                  post.category.toUpperCase(),
                  style: AppTypography.label(size: 8, color: base),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.').format(post.createdAt),
                  style: AppTypography.caption(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                post.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (post.commentCount > 0) ...[
                  const Icon(LucideIcons.messageSquare,
                      size: 11, color: AppColors.inkSoft),
                  const SizedBox(width: 3),
                  Text('${post.commentCount}',
                      style: AppTypography.caption()),
                  const SizedBox(width: 10),
                ],
                if (post.pinCount > 0) ...[
                  const Icon(LucideIcons.pin,
                      size: 11, color: AppColors.amber),
                  const SizedBox(width: 3),
                  Text('${post.pinCount}',
                      style: AppTypography.caption()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
