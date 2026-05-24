import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/group.dart';
import '../../../repositories/groups_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _filter = 'all';
  String _search = '';

  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'nachbarschaft', label: '🏘️ Nachbarschaft'),
    FilterOption(value: 'hobby', label: '🎨 Hobby'),
    FilterOption(value: 'sport', label: '⚽ Sport'),
    FilterOption(value: 'eltern', label: '👨‍👩‍👧 Eltern'),
    FilterOption(value: 'senioren', label: '👴 Senioren'),
    FilterOption(value: 'umwelt', label: '🌱 Umwelt'),
    FilterOption(value: 'bildung', label: '📚 Bildung'),
    FilterOption(value: 'tiere', label: '🐾 Tiere'),
    FilterOption(value: 'handwerk', label: '🔧 Handwerk'),
    FilterOption(value: 'sonstiges', label: '❓ Sonstiges'),
  ];

  bool get _hasFilters => _filter != 'all' || _search.isNotEmpty;

  List<Group> _apply(List<Group> all) {
    final q = _search.trim().toLowerCase();
    return all.where((g) {
      if (_filter != 'all' && g.category != _filter) return false;
      if (q.isEmpty) return true;
      return g.name.toLowerCase().contains(q) ||
          (g.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupsListProvider);
    return DashboardScaffold(
      title: 'groups.screenTitle'.tr(),
      currentRoute: '/dashboard/groups',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/groups/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('groups.create'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 08',
                metaCategory: 'groups.screenTitle'.tr(),
                title: 'modules.groupsHero.title'.tr(),
                subtitle: 'modules.groupsHero.subtitle'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: ModuleSearchBar(
                hintText: 'groups.searchPlaceholder'.tr(),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _categories,
                selected: _filter == 'all' ? const <String>{} : {_filter},
                onChanged: (s) =>
                    setState(() => _filter = s.isEmpty ? 'all' : s.first),
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_filter != 'all')
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _filter)
                            .label,
                        onRemove: () => setState(() => _filter = 'all'),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _filter = 'all';
                    _search = '';
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.invalidate(groupsListProvider),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                  error: (e, _) => Center(
                      child: Text('$e', style: AppTypography.caption())),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.users2,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Noch keine Gruppen.',
                            description: _hasFilters
                                ? 'Andere Filter probieren.'
                                : 'Gründe die erste Gruppe!',
                            actionLabel: _hasFilters
                                ? 'Filter zurücksetzen'
                                : 'Gruppe erstellen',
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _filter = 'all';
                                      _search = '';
                                    })
                                : () =>
                                    context.go('/dashboard/groups/create'),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) =>
                          _Tile(group: list[i]),
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

class _Tile extends StatelessWidget {
  const _Tile({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = group.avatarUrl ?? group.bannerUrl;
    return InkWell(
      onTap: () => context.go('/dashboard/groups/${group.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.elevated,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? const Icon(LucideIcons.users2,
                      size: 18, color: AppColors.amber)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (group.isPrivate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.bronze.withValues(alpha: 0.14),
                            border: Border.all(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.lock,
                                  size: 9,
                                  color: AppColors.bronze),
                              const SizedBox(width: 3),
                              Text('PRIVAT',
                                  style: AppTypography.label(
                                      size: 7,
                                      color: AppColors.bronze)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(group.category,
                            style: AppTypography.label(size: 8)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.users,
                          size: 11, color: AppColors.tealSoft),
                      const SizedBox(width: 3),
                      Text('${group.memberCount}',
                          style: AppTypography.mono(
                              size: 10, color: AppColors.tealSoft)),
                      const SizedBox(width: 2),
                      Text(
                        group.memberCount == 1
                            ? 'Mitglied'
                            : 'Mitglieder',
                        style: AppTypography.label(
                            size: 9, color: AppColors.mute),
                      ),
                    ],
                  ),
                  if (group.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
