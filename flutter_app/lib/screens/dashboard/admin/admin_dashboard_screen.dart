import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// Uebersicht aller Admin-Bereiche mit Live-Counts.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return DashboardScaffold(
      title: 'Admin',
      currentRoute: '/dashboard/admin',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            await ref.read(adminStatsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              const SizedBox(height: 16),
              statsAsync.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.amber),
                  ),
                ),
                error: (_, __) => Text('Stats konnten nicht geladen werden.',
                    style: AppTypography.caption()),
                data: (s) => _AdminGrid(stats: s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.shieldCheck,
              color: AppColors.amber, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin-Cockpit',
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              Text('Übersicht & Moderation aller Module.',
                  style: AppTypography.caption()),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminGrid extends StatelessWidget {
  const _AdminGrid({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <_AdminTile>[
      _AdminTile(
        title: 'Users',
        count: stats.users,
        icon: LucideIcons.users,
        color: AppColors.tealSoft,
        route: '/dashboard/admin/users',
      ),
      _AdminTile(
        title: 'Posts',
        count: stats.posts,
        icon: LucideIcons.fileText,
        color: AppColors.amber,
        route: '/dashboard/admin/posts',
      ),
      _AdminTile(
        title: 'Events',
        count: stats.events,
        icon: LucideIcons.calendar,
        color: AppColors.tealSoft,
        route: '/dashboard/admin/events',
      ),
      _AdminTile(
        title: 'Board',
        count: stats.boardPosts,
        icon: LucideIcons.layoutDashboard,
        color: AppColors.amber,
        route: '/dashboard/admin/board',
      ),
      _AdminTile(
        title: 'Krisen',
        count: stats.crises,
        icon: LucideIcons.alertTriangle,
        color: AppColors.herzrotWarm,
        route: '/dashboard/admin/crisis',
      ),
      _AdminTile(
        title: 'Organisationen',
        count: stats.organizations,
        icon: LucideIcons.building2,
        color: AppColors.tealSoft,
        route: '/dashboard/admin/organizations',
      ),
      _AdminTile(
        title: 'Farms',
        count: stats.farms,
        icon: LucideIcons.wheat,
        color: AppColors.lebenSoft,
        route: '/dashboard/admin/farms',
      ),
      _AdminTile(
        title: 'Reports',
        count: stats.reports,
        icon: LucideIcons.flag,
        color: AppColors.herzrot,
        route: '/dashboard/admin/chat-moderation',
      ),
      const _AdminTile(
        title: 'System',
        count: 0,
        icon: LucideIcons.settings,
        color: AppColors.mute,
        route: '/dashboard/admin/system',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) => tiles[i],
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(
              '$count',
              style: AppTypography.mono(size: 26, color: AppColors.ink),
            ),
            const SizedBox(height: 2),
            Text(title, style: AppTypography.label(size: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
