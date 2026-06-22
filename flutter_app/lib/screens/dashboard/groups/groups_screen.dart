import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/shared/sized_avatar_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/group.dart';
import '../../../repositories/groups_repository.dart';
import '../../../widgets/groups/nearby_groups_carousel.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/skeleton_card.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _filter = 'all';
  String _search = '';

  List<FilterOption<String>> get _categories => [
        FilterOption(
            value: 'nachbarschaft',
            label: '🏘️ ${'groups.catNachbarschaft'.tr()}'),
        FilterOption(value: 'hobby', label: '🎨 ${'groups.catHobby'.tr()}'),
        FilterOption(value: 'sport', label: '⚽ ${'groups.catSport'.tr()}'),
        FilterOption(
            value: 'eltern', label: '👨‍👩‍👧 ${'groups.catEltern'.tr()}'),
        FilterOption(
            value: 'senioren', label: '👴 ${'groups.catSenioren'.tr()}'),
        FilterOption(value: 'umwelt', label: '🌱 ${'groups.catUmwelt'.tr()}'),
        FilterOption(value: 'bildung', label: '📚 ${'groups.catBildung'.tr()}'),
        FilterOption(value: 'tiere', label: '🐾 ${'groups.catTiere'.tr()}'),
        FilterOption(
            value: 'handwerk', label: '🔧 ${'groups.catHandwerk'.tr()}'),
        FilterOption(
            value: 'sonstiges', label: '❓ ${'groups.catSonstiges'.tr()}'),
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
        onPressed: () => context.push('/dashboard/groups/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('groups.create'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Editorial-Header in die scrollbare Liste verschoben → mehr Platz
            // für die Gruppenliste (weniger fixe Kopfzeile).
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
                        label: _categories.labelFor(_filter),
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
                  loading: () =>
                      const SkeletonList(count: 6, itemHeight: 84),
                  error: (e, _) => Center(
                    child: ErrorStateWidget(
                      onRetry: () => ref.invalidate(groupsListProvider),
                    ),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          EditorialModuleHeader(
                            metaIndex: '§ 08',
                            metaCategory: 'groups.screenTitle'.tr(),
                            title: 'modules.groupsHero.title'.tr(),
                            subtitle: 'modules.groupsHero.subtitle'.tr(),
                          ),
                          const SizedBox(height: 40),
                          EmptyStateWidget(
                            icon: LucideIcons.users2,
                            title: _hasFilters
                                ? 'search.noResultsShort'.tr()
                                : 'groups.empty'.tr(),
                            subtitle: _hasFilters
                                ? 'modules.tryOtherFilters'.tr()
                                : 'groups.emptyHint'.tr(),
                            actionLabel: _hasFilters
                                ? 'posts.resetFilter'.tr()
                                : 'groups.create'.tr(),
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _filter = 'all';
                                      _search = '';
                                    })
                                : () =>
                                    context.push('/dashboard/groups/create'),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      // i0 = Editorial-Header (aus dem fixen Kopf verschoben →
                      // mehr Platz), i1 = Nachbarschafts-Carousel (nur sichtbar
                      // bei GPS + Group im Radius), danach die Gruppen.
                      itemCount: list.length + 2,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: EditorialModuleHeader(
                              metaIndex: '§ 08',
                              metaCategory: 'groups.screenTitle'.tr(),
                              title: 'modules.groupsHero.title'.tr(),
                              subtitle: 'modules.groupsHero.subtitle'.tr(),
                            ),
                          );
                        }
                        if (i == 1) return const NearbyGroupsCarousel();
                        return AnimatedEntrance(
                          index: i,
                          child: _Tile(group: list[i - 2]),
                        );
                      },
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
      onTap: () => context.push('/dashboard/groups/${group.id}'),
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
            if (avatarUrl != null)
              SizedAvatarImage(
                url: avatarUrl,
                size: 44,
              )
            else
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.elevated,
                child: Icon(LucideIcons.users2,
                    size: 18, color: AppColors.amber),
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
                              Text('groupsModule.privateBadge'.tr(),
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
