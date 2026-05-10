import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/realtime_feed.dart';
import 'groups_repository.dart';
import 'models.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage>
    with RealtimeFeedMixin {
  List<Group> _groups = [];
  Set<String> _mine = const {};
  bool _loading = true;
  String _category = 'all';
  String? _busyId;

  @override
  String get realtimeChannelName => 'groups-feed-realtime';

  @override
  List<FeedRealtimeRule> get realtimeRules => const [
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'groups',
          action: FeedRealtimeAction.bumpNewCount,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.update,
          table: 'groups',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'group_members',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.delete,
          table: 'group_members',
          action: FeedRealtimeAction.reloadImmediately,
        ),
      ];

  @override
  Future<void> reloadFeed() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    subscribeRealtime();
  }

  void _showNewItems() {
    resetNewItemCount();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(groupsRepositoryProvider);
      final list = await repo.list(category: _category);
      final mine = await repo.myGroupIds();
      if (!mounted) return;
      setState(() {
        _groups = list;
        _mine = mine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _toggle(Group g) async {
    HapticFeedback.mediumImpact();
    setState(() => _busyId = g.id);
    try {
      final repo = ref.read(groupsRepositoryProvider);
      if (_mine.contains(g.id)) {
        await repo.leave(g.id);
      } else {
        await repo.join(g.id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gruppen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Gruppe erstellen',
            onPressed: () => context.go(Routes.dashboardGroupsCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          const HeroHeader(
            metaLabel: 'Gruppen',
            title: 'Deine Nachbarschaft, organisiert',
            subtitle:
                'Nachbarschaftsgruppen, Hobby-Runden und Aktionsgruppen — finde Gleichgesinnte oder gründe deine eigene.',
            icon: Icons.group_outlined,
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Alle',
                  selected: _category == 'all',
                  onTap: () {
                    setState(() => _category = 'all');
                    _load();
                  },
                ),
                ...GroupCategory.all.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(
                      label: '${c.emoji} ${c.label}',
                      selected: _category == c.value,
                      color: c.accent,
                      onTap: () {
                        setState(() => _category = c.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          NewItemsBanner(
            count: newItemCount,
            singularLabel: 'Gruppe',
            pluralLabel: 'Gruppen',
            onTap: _showNewItems,
            icon: Icons.group_add_outlined,
          ),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 4)
                : _groups.isEmpty
                    ? EmptyState(
                        emoji: '👥',
                        title: 'Noch keine Gruppen',
                        subtitle:
                            'Sei die erste Gruppe in dieser Kategorie — du gibst den Ton an.',
                        actionLabel: 'Gruppe gründen',
                        onAction: () =>
                            context.go(Routes.dashboardGroupsCreate),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _groups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _GroupCard(
                            group: _groups[i],
                            isMember: _mine.contains(_groups[i].id),
                            busy: _busyId == _groups[i].id,
                            onToggle: () => _toggle(_groups[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary500;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? accent : AppColors.ink700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isMember,
    required this.busy,
    required this.onToggle,
  });

  final Group group;
  final bool isMember;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cat = group.categoryConfig;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('${Routes.dashboardGroups}/${group.slug}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cat.accent.withValues(alpha: 0.18),
                backgroundImage: group.displayImage != null
                    ? NetworkImage(group.displayImage!)
                    : null,
                child: group.displayImage == null
                    ? Text(cat.emoji, style: const TextStyle(fontSize: 22))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isPrivate) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock, size: 12, color: AppColors.ink400),
                        ],
                      ],
                    ),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: cat.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((group.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.ink700),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 12, color: AppColors.ink400),
                        const SizedBox(width: 2),
                        Text(
                          '${group.memberCount} Mitglieder',
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: isMember
                    ? OutlinedButton(
                        onPressed: busy ? null : onToggle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink700,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Mitglied'),
                      )
                    : FilledButton(
                        onPressed: busy ? null : onToggle,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Beitreten'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
