import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_badge.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_stat.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/supabase_service.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  static const _labels = [
    'Uebersicht',
    'Users',
    'Posts',
    'Events',
    'Board',
    'Krise',
    'Orgs',
    'Hoefe',
    'Chat-Mod',
    'System',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isAdmin = profile?['is_admin'] == true;

    if (!isAdmin) {
      // Redirect zu Dashboard bei Nicht-Admins.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GoRouter.of(context).go('/dashboard');
      });
      return const CinemaScaffold(body: SizedBox.shrink());
    }

    return CinemaScaffold(
      level: AtmosphereLevel.focus,
      appBar: const CinemaAppBar(title: 'ADMIN'),
      body: SafeArea(
        child: Column(
          children: [
            CinemaTabs(controller: _tabs, labels: _labels),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _OverviewTab(),
                  _SimpleListTab(table: 'profiles', label: 'Profile'),
                  _SimpleListTab(table: 'posts', label: 'Posts'),
                  _SimpleListTab(table: 'events', label: 'Events'),
                  _SimpleListTab(table: 'board_posts', label: 'Board'),
                  _CrisisTab(),
                  _SimpleListTab(table: 'organizations', label: 'Organisationen'),
                  _SimpleListTab(table: 'farm_listings', label: 'Bauernhoefe'),
                  _SimpleListTab(table: 'content_reports', label: 'Reports'),
                  _SystemTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final tables = [
    'profiles',
    'posts',
    'events',
    'conversations',
    'messages',
    'notifications',
    'content_reports',
    'crises',
  ];
  final result = <String, int>{};
  for (final t in tables) {
    try {
      final res = await supabase.client.from(t).select('id');
      result[t] = (res as List).length;
    } catch (_) {
      result[t] = 0;
    }
  }
  return result;
});

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_adminStatsProvider);
    return stats.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
      data: (s) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          CinemaStat(value: s['profiles'] ?? 0, label: 'Profile', icon: LucideIcons.users),
          CinemaStat(value: s['posts'] ?? 0, label: 'Posts', icon: LucideIcons.fileText),
          CinemaStat(value: s['events'] ?? 0, label: 'Events', icon: LucideIcons.calendar),
          CinemaStat(value: s['conversations'] ?? 0, label: 'Conversations', icon: LucideIcons.messageCircle),
          CinemaStat(value: s['messages'] ?? 0, label: 'Messages', icon: LucideIcons.send),
          CinemaStat(value: s['notifications'] ?? 0, label: 'Notifications', icon: LucideIcons.bell),
          CinemaStat(
            value: s['content_reports'] ?? 0,
            label: 'Reports',
            icon: LucideIcons.alertTriangle,
            valueColor: MnColors.herzrot,
          ),
          CinemaStat(
            value: s['crises'] ?? 0,
            label: 'Krisen aktiv',
            icon: LucideIcons.alertCircle,
            valueColor: MnColors.herzrot,
          ),
        ],
      ),
    );
  }
}

class _SimpleListTab extends ConsumerWidget {
  final String table;
  final String label;
  const _SimpleListTab({required this.table, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_tableProvider(table));
    return data.when(
      loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
      data: (rows) {
        if (rows.isEmpty) {
          return CinemaEmptyState(
            icon: LucideIcons.database,
            title: 'Keine Eintraege in $label.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MnColors.elevated,
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (r['title'] as String?) ??
                        (r['full_name'] as String?) ??
                        (r['name'] as String?) ??
                        (r['id'] as String?) ??
                        '',
                    style: MnTypography.body(weight: FontWeight.w600),
                  ),
                  if (r['created_at'] != null)
                    Text(
                      r['created_at'].toString(),
                      style: MnTypography.mono(size: 11, color: MnColors.mute),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

final _tableProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, table) async {
  final res = await supabase.client
      .from(table)
      .select()
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res as List);
});

class _CrisisTab extends ConsumerWidget {
  const _CrisisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crises = ref.watch(_tableProvider('crises'));
    return Container(
      color: MnColors.herzrotDeep.withValues(alpha: 0.08),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlowButton(
            label: 'Krisenmodus aktivieren',
            variant: GlowVariant.crisis,
            fullWidth: true,
            icon: LucideIcons.alertTriangle,
            onPressed: () {
              // TODO Phase 9: CinemaModal Form mit region/description/typ.
            },
          ),
          const SizedBox(height: 16),
          crises.when(
            loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.text),
            error: (e, _) => Text('$e', style: MnTypography.body()),
            data: (rows) => Column(
              children: rows.map((r) {
                final active = r['active'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MnColors.elevated,
                    borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (r['type'] as String?) ?? 'Krise',
                              style: MnTypography.body(weight: FontWeight.w600),
                            ),
                            Text(
                              (r['description'] as String?) ?? '',
                              style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                            ),
                          ],
                        ),
                      ),
                      CinemaBadge(
                        label: active ? 'aktiv' : 'beendet',
                        variant: active ? BadgeVariant.herzrot : BadgeVariant.mute,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemTab extends StatelessWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('System-Status', style: MnTypography.display(size: 20)),
        const SizedBox(height: 16),
        Text(
          'Supabase Project: huaqldjkgyosefzfhjnf',
          style: MnTypography.mono(size: 12, color: MnColors.mute),
        ),
        const SizedBox(height: 8),
        Text(
          'Storage Buckets: avatars, post-images, chat-media, board-images, '
          'event-images, marketplace, wiki-images, group-images',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'RLS-Policies: aktiv auf allen 37+ Tabellen.',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
      ],
    );
  }
}
