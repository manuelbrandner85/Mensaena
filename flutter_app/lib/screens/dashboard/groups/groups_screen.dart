import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/group.dart';
import '../../../repositories/groups_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _filter = 'all';

  static const List<({String value, String label})> _categories = [
    (value: 'all', label: 'Alle'),
    (value: 'nachbarschaft', label: 'Nachbarschaft'),
    (value: 'hobby', label: 'Hobby'),
    (value: 'sport', label: 'Sport'),
    (value: 'eltern', label: 'Eltern'),
    (value: 'senioren', label: 'Senioren'),
    (value: 'umwelt', label: 'Umwelt'),
    (value: 'bildung', label: 'Bildung'),
    (value: 'tiere', label: 'Tiere'),
    (value: 'handwerk', label: 'Handwerk'),
    (value: 'sonstiges', label: 'Sonstiges'),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupsListProvider);
    return DashboardScaffold(
      title: 'Gruppen',
      currentRoute: '/dashboard/groups',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/groups/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Gruppe erstellen'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final active = c.value == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = c.value),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.amber.withValues(alpha: 0.2)
                            : AppColors.surface.withValues(alpha: 0.5),
                        border: Border.all(
                          color: active ? AppColors.amber : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c.label,
                        style: AppTypography.label(
                          size: 10,
                          color: active
                              ? AppColors.amber
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.invalidate(groupsListProvider),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                  error: (e, _) =>
                      Center(child: Text('$e', style: AppTypography.caption())),
                  data: (all) {
                    final list = _filter == 'all'
                        ? all
                        : all.where((g) => g.category == _filter).toList();
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                const Icon(LucideIcons.users2,
                                    size: 32, color: AppColors.mute),
                                const SizedBox(height: 10),
                                Text('Keine Gruppen in dieser Kategorie.',
                                    style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.mute,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _Tile(group: list[i]),
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
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.lock,
                              size: 12, color: AppColors.mute),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(group.category,
                          style: AppTypography.label(size: 9)),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.users,
                          size: 10, color: AppColors.mute),
                      const SizedBox(width: 3),
                      Text('${group.memberCount}',
                          style: AppTypography.caption()),
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
