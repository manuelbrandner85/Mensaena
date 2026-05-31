import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (Admin Phase 6)
/// Web-parity admin dashboard: open-reports alert, stat-cards strip,
/// activity feed + quick actions, platform-overview grid.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardScaffold(
      title: 'admin.adminTitle'.tr(),
      currentRoute: '/dashboard/admin',
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        ref.invalidate(adminAuditLogsProvider);
        ref.invalidate(adminOpenReportsProvider);
        ref.invalidate(adminUserGrowthProvider);
        await ref.read(adminStatsProvider.future);
      },
      body: const SafeArea(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OpenReportsAlert(),
              _UsersOverviewCard(),
              SizedBox(height: 16),
              _UserGrowthCard(),
              SizedBox(height: 16),
              _StatsStrip(),
              SizedBox(height: 16),
              _ActivityAndActions(),
              SizedBox(height: 16),
              _PlatformOverview(),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open reports alert banner.
// ---------------------------------------------------------------------------

class _OpenReportsAlert extends ConsumerWidget {
  const _OpenReportsAlert();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminOpenReportsProvider);
    return reports.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (count) {
        if (count <= 0) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/dashboard/admin/chat-moderation'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.herzrot.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.herzrot.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.flag,
                    color: AppColors.herzrot, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'admin.openReportsAlert'.tr(
                      namedArgs: {'count': '$count'},
                    ),
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
                    color: AppColors.herzrot, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero-Karte: Gesamt-Nutzer:innen prominent + Aufschlüsselung (Aktiv 24h/7d/
// 30d, Neu 24h/7d/30d, Admins, Moderator:innen, Gebannte). Antwort auf den
// User-Wunsch "Gesamt Nutzer in Zahlen anzeigen" — vorher waren alle Headline-
// Zahlen wegen RPC-Key-Mismatch (`total_users` vs. `users`) konstant 0.
// ---------------------------------------------------------------------------

class _UsersOverviewCard extends ConsumerWidget {
  const _UsersOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bronze.withValues(alpha: 0.18),
            AppColors.amber.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.users,
                  color: AppColors.bronze, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'admin.usersOverviewTitle'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/dashboard/admin/users'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.bronze,
                  minimumSize: const Size(0, 32),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('admin.openDetails'.tr(),
                        style: AppTypography.body(
                            size: 12,
                            color: AppColors.bronze,
                            weight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.chevronRight,
                        size: 16, color: AppColors.bronze),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          statsAsync.when(
            loading: () => const _UsersOverviewSkeleton(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('admin.statsLoadShort'.tr(),
                  style: AppTypography.caption()),
            ),
            data: (s) => _UsersOverviewContent(stats: s),
          ),
        ],
      ),
    );
  }
}

class _UsersOverviewSkeleton extends StatelessWidget {
  const _UsersOverviewSkeleton();
  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(height: 56, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerBox(height: 90, borderRadius: 12),
        ],
      );
}

class _UsersOverviewContent extends StatelessWidget {
  const _UsersOverviewContent({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero: Gesamtzahl. Prominent, mit Subtitle.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatNumber(stats.users),
              style: AppTypography.mono(
                size: 44,
                color: AppColors.ink,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('admin.totalUsers'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  Text('admin.totalUsersHint'.tr(),
                      style: AppTypography.caption()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Aufschlüsselung als responsives Mini-Grid.
        LayoutBuilder(
          builder: (ctx, c) {
            final cols = c.maxWidth >= 520 ? 4 : 2;
            final tiles = <_MiniTile>[
              _MiniTile(
                  icon: LucideIcons.activity,
                  label: 'admin.active24h'.tr(),
                  value: stats.activeUsers24h,
                  color: AppColors.leben),
              _MiniTile(
                  icon: LucideIcons.activity,
                  label: 'admin.active7d'.tr(),
                  value: stats.activeUsers7d,
                  color: AppColors.teal),
              _MiniTile(
                  icon: LucideIcons.activity,
                  label: 'admin.active30d'.tr(),
                  value: stats.activeUsers30d,
                  color: AppColors.amber),
              _MiniTile(
                  icon: LucideIcons.userPlus,
                  label: 'admin.newUsers24h'.tr(),
                  value: stats.newUsers24h,
                  color: AppColors.leben),
              _MiniTile(
                  icon: LucideIcons.userPlus,
                  label: 'admin.newUsers7d'.tr(),
                  value: stats.newUsers7d,
                  color: AppColors.teal),
              _MiniTile(
                  icon: LucideIcons.userPlus,
                  label: 'admin.newUsers30d'.tr(),
                  value: stats.newUsers30d,
                  color: AppColors.amber),
              _MiniTile(
                  icon: LucideIcons.shieldCheck,
                  label: 'admin.roleAdmins'.tr(),
                  value: stats.admins,
                  color: AppColors.bronze),
              _MiniTile(
                  icon: LucideIcons.shield,
                  label: 'admin.roleModerators'.tr(),
                  value: stats.moderators,
                  color: AppColors.bronze),
              if (stats.bannedUsers > 0)
                _MiniTile(
                    icon: LucideIcons.ban,
                    label: 'admin.banned'.tr(),
                    value: stats.bannedUsers,
                    color: AppColors.herzrot),
            ];
            return GridView.count(
              crossAxisCount: cols,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final t in tiles) _MiniTileView(data: t)],
            );
          },
        ),
      ],
    );
  }

  // Tausender-Trenner gemäß System-Locale; bei kleinen Zahlen sieht es
  // identisch aus, bei 10.000+ wird es sofort lesbar.
  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _MiniTile {
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int value;
  final Color color;
}

class _MiniTileView extends StatelessWidget {
  const _MiniTileView({required this.data});
  final _MiniTile data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.10),
        border: Border.all(color: data.color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 14, color: data.color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${data.value}',
                    style: AppTypography.mono(
                        size: 16,
                        color: AppColors.ink,
                        weight: FontWeight.w800)),
                Text(data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                        size: 9, color: AppColors.mute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal stat-cards strip (5 cards).
// ---------------------------------------------------------------------------

class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return SizedBox(
      height: 110,
      child: statsAsync.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => const ShimmerBox(
            width: 140,
            height: 100,
            borderRadius: 14,
          ),
        ),
        error: (_, __) => Center(
          child: Text(
            'admin.statsLoadShort'.tr(),
            style: AppTypography.caption(),
          ),
        ),
        data: (s) {
          final items = <_StatCardData>[
            _StatCardData(
              icon: LucideIcons.users,
              accent: AppColors.amber,
              value: '${s.users}',
              subtitle: 'admin.statUsersSub'.tr(
                namedArgs: {'active': '${s.activeUsers30d}'},
              ),
            ),
            _StatCardData(
              icon: LucideIcons.userPlus,
              accent: AppColors.leben,
              value: '${s.newUsers7d}',
              subtitle: 'admin.statNewUsers'.tr(),
            ),
            _StatCardData(
              icon: LucideIcons.users2,
              accent: AppColors.teal,
              value: '${s.activeGroups}',
              subtitle: 'admin.statActiveGroupsSub'.tr(
                namedArgs: {'total': '${s.totalGroups}'},
              ),
            ),
            _StatCardData(
              icon: LucideIcons.trophy,
              accent: AppColors.amber,
              value: '${s.activeChallenges}',
              subtitle: 'admin.statActiveChallenges'.tr(),
            ),
            _StatCardData(
              icon: LucideIcons.clock,
              accent: AppColors.bronze,
              value: '${s.totalTimebankHours.toStringAsFixed(0)}h',
              subtitle: 'admin.statTimebankSub'.tr(),
            ),
          ];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _StatCard(data: items[i]),
          );
        },
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.accent,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final Color accent;
  final String value;
  final String subtitle;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: 0.06),
        border: Border.all(color: data.accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.accent, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: AppTypography.mono(
              size: 22,
              color: AppColors.ink,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              data.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(size: 9, color: AppColors.mute),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity feed + quick actions (responsive: side-by-side on wide screens).
// ---------------------------------------------------------------------------

class _ActivityAndActions extends StatelessWidget {
  const _ActivityAndActions();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final wide = c.maxWidth >= 700;
        if (wide) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _ActivityFeed()),
              SizedBox(width: 16),
              Expanded(flex: 1, child: _QuickActions()),
            ],
          );
        }
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActivityFeed(),
            SizedBox(height: 16),
            _QuickActions(),
          ],
        );
      },
    );
  }
}

class _ActivityFeed extends ConsumerWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.recentActivity'.tr(),
                  style: AppTypography.display(
                      size: 16, color: AppColors.ink),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => context.go('/dashboard/admin/system'),
                child: Text(
                  'admin.allEntries'.tr(),
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.amber,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          logs.when(
            loading: () => Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: ShimmerBox(height: 48, borderRadius: 8),
                ),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'admin.noActivity'.tr(),
                style: AppTypography.caption(),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'admin.noActivity'.tr(),
                    style: AppTypography.caption(),
                  ),
                );
              }
              final limited = rows.take(8).toList();
              return Column(
                children: [
                  for (var i = 0; i < limited.length; i++) ...[
                    _ActivityRow(entry: limited[i]),
                    if (i < limited.length - 1)
                      const Divider(
                        color: AppColors.line,
                        height: 1,
                        thickness: 1,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final Map<String, dynamic> entry;

  IconData _iconForAction(String action) {
    switch (action) {
      case 'delete_user':
        return LucideIcons.userX;
      case 'ban_user':
        return LucideIcons.ban;
      case 'change_role':
        return LucideIcons.shieldCheck;
      case 'resolve_report':
        return LucideIcons.flag;
      default:
        return LucideIcons.activity;
    }
  }

  String _relativeTime(DateTime? then) {
    if (then == null) return '';
    final diff = DateTime.now().difference(then);
    if (diff.inSeconds < 60) return 'admin.relTime.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'admin.relTime.minAgo'
          .tr(namedArgs: {'min': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'admin.relTime.hAgo'.tr(namedArgs: {'h': '${diff.inHours}'});
    }
    return 'admin.relTime.dAgo'.tr(namedArgs: {'d': '${diff.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final action = (entry['action'] ?? '').toString();
    final profile = entry['profiles'];
    final actorName = (profile is Map && profile['name'] is String)
        ? profile['name'] as String
        : (entry['actor_id']?.toString() ?? '—');
    final createdRaw = entry['created_at']?.toString();
    final created = createdRaw != null ? DateTime.tryParse(createdRaw) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForAction(action), size: 16, color: AppColors.mute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w600),
                ),
                Text(
                  action.isEmpty ? '—' : action.replaceAll('_', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_relativeTime(created), style: AppTypography.caption()),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.quickActions'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          const _BroadcastButton(),
          const SizedBox(height: 8),
          _ActionButton(
            icon: LucideIcons.users,
            label: 'admin.manageUsers'.tr(),
            route: '/dashboard/admin/users',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: LucideIcons.trophy,
            label: 'admin.createChallenge'.tr(),
            route: '/dashboard/admin/challenges',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: LucideIcons.users2,
            label: 'admin.manageGroups'.tr(),
            route: '/dashboard/admin/groups',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: LucideIcons.clock,
            label: 'admin.checkTimebank'.tr(),
            route: '/dashboard/admin/timebank',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.go(route),
        icon: Icon(icon, size: 18, color: AppColors.ink),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
                size: 13,
                color: AppColors.ink,
                weight: FontWeight.w600),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.line),
          backgroundColor: AppColors.surface.withValues(alpha: 0.4),
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Broadcast: Ankündigung an alle Nutzer:innen (Composer-Sheet + RPC).
// ---------------------------------------------------------------------------

class _BroadcastButton extends StatelessWidget {
  const _BroadcastButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _BroadcastSheet(),
        ),
        icon: const Icon(LucideIcons.megaphone, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'admin.broadcast'.tr(),
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
                size: 13,
                color: AppColors.voidColor,
                weight: FontWeight.w700),
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: AppColors.voidColor,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _BroadcastSheet extends ConsumerStatefulWidget {
  const _BroadcastSheet();

  @override
  ConsumerState<_BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends ConsumerState<_BroadcastSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _priority = 'normal';
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.broadcastEmpty'.tr())),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(LucideIcons.megaphone,
            size: 28, color: AppColors.bronze),
        content: Text('admin.broadcastConfirm'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(
                size: 14, color: AppColors.ink, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.voidColor),
            child: Text('admin.broadcastSend'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sending = true);
    final count = await AdminRepository.broadcastNotification(
      title: title,
      body: body,
      link: _link.text,
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (count == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.broadcastFailed'.tr())),
      );
      return;
    }
    // Notification-Count im Dashboard auffrischen.
    ref.invalidate(adminStatsProvider);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.broadcastSuccess'
            .tr(namedArgs: {'count': '$count'})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(LucideIcons.megaphone,
                      size: 20, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('admin.broadcastTitle'.tr(),
                        style: AppTypography.display(
                            size: 18, color: AppColors.ink)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('admin.broadcastDesc'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                maxLength: 120,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'admin.broadcastFieldTitle'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 500,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'admin.broadcastFieldBody'.tr(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _link,
                keyboardType: TextInputType.url,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'admin.broadcastFieldLink'.tr(),
                  prefixIcon: const Icon(LucideIcons.link, size: 16),
                ),
              ),
              const SizedBox(height: 14),
              Text('admin.broadcastPriority'.tr(),
                  style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in const [
                    ('low', 'admin.prioLow'),
                    ('normal', 'admin.prioNormal'),
                    ('high', 'admin.prioHigh'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.$2.tr()),
                        selected: _priority == p.$1,
                        onSelected: (_) =>
                            setState(() => _priority = p.$1),
                        selectedColor:
                            AppColors.bronze.withValues(alpha: 0.25),
                        labelStyle: AppTypography.label(
                          size: 11,
                          color: _priority == p.$1
                              ? AppColors.bronze
                              : AppColors.inkSoft,
                        ),
                        backgroundColor:
                            AppColors.elevated.withValues(alpha: 0.5),
                        side: BorderSide(
                          color: _priority == p.$1
                              ? AppColors.bronze
                              : AppColors.line,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.voidColor),
                        )
                      : const Icon(LucideIcons.send, size: 18),
                  label: Text(_sending
                      ? 'admin.broadcastSending'.tr()
                      : 'admin.broadcastSend'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    textStyle: AppTypography.body(
                        size: 15, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nutzer-Zuwachs-Chart (Tagesreihe + kumulative Linie). Pure CustomPaint,
// keine externe Chart-Dependency. Range-Toggle 14 / 30 Tage.
// ---------------------------------------------------------------------------

class _UserGrowthCard extends ConsumerStatefulWidget {
  const _UserGrowthCard();

  @override
  ConsumerState<_UserGrowthCard> createState() => _UserGrowthCardState();
}

class _UserGrowthCardState extends ConsumerState<_UserGrowthCard> {
  int _days = 14;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminUserGrowthProvider(_days));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingUp,
                  color: AppColors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('admin.growthTitle'.tr(),
                        style: AppTypography.display(
                            size: 16, color: AppColors.ink)),
                    Text('admin.growthSubtitle'.tr(),
                        style: AppTypography.caption()),
                  ],
                ),
              ),
              _RangeToggle(
                value: _days,
                onChanged: (v) => setState(() => _days = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: async.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.amber),
                ),
              ),
              error: (_, __) => Center(
                child: Text('admin.statsLoadShort'.tr(),
                    style: AppTypography.caption()),
              ),
              data: (points) {
                if (points.isEmpty) {
                  return Center(
                    child: Text('admin.growthEmpty'.tr(),
                        style: AppTypography.caption()),
                  );
                }
                return _GrowthChart(points: points);
              },
            ),
          ),
          const SizedBox(height: 10),
          // Legende.
          Row(
            children: [
              _LegendDot(
                  color: AppColors.amber,
                  label: 'admin.growthLegendNew'.tr()),
              const SizedBox(width: 14),
              _LegendDot(
                  color: AppColors.bronze,
                  label: 'admin.growthLegendTotal'.tr(),
                  isLine: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(int days, String key) {
      final active = value == days;
      return GestureDetector(
        onTap: () => onChanged(days),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.bronze.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(key.tr(),
              style: AppTypography.label(
                size: 10,
                color: active ? AppColors.bronze : AppColors.inkSoft,
                weight: active ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(14, 'admin.range14d'),
          seg(30, 'admin.range30d'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.isLine = false,
  });
  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 16 : 10,
          height: isLine ? 2 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 1 : 5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption()),
      ],
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.points});
  final List<UserGrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => CustomPaint(
        size: Size(c.maxWidth, c.maxHeight),
        painter: _GrowthChartPainter(points: points),
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({required this.points});
  final List<UserGrowthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padLeft = 28.0;
    const padRight = 28.0;
    const padTop = 6.0;
    const padBottom = 22.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    // Achsen-Range.
    final maxNew =
        points.map((p) => p.newUsers).fold<int>(0, (a, b) => a > b ? a : b);
    final maxCum = points
        .map((p) => p.cumulative)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final scaleNew = maxNew == 0 ? 1.0 : maxNew.toDouble();
    final scaleCum = maxCum == 0 ? 1.0 : maxCum.toDouble();

    // Hilfslinien (3 horizontale).
    final gridPaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = padTop + chartH * i / 3;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
    }

    // Y-Labels: rechtsbündig links (Neu pro Tag, 0 + max) und rechts
    // (kumulative Linie, max).
    void drawText(String s, Offset at,
        {TextAlign align = TextAlign.left, Color? color, double width = 40}) {
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
      ))
        ..pushStyle(ui.TextStyle(
          color: color ?? AppColors.mute,
          fontSize: 9,
          height: 1.0,
        ))
        ..addText(s);
      final p = pb.build()..layout(ui.ParagraphConstraints(width: width));
      canvas.drawParagraph(p, at);
    }

    // Links: 0 + max(neu).
    drawText('$maxNew', const Offset(0, padTop - 2),
        align: TextAlign.right, color: AppColors.amber, width: padLeft - 4);
    drawText('0', Offset(0, padTop + chartH - 8),
        align: TextAlign.right, width: padLeft - 4);
    // Rechts: max(cumulative).
    drawText('$maxCum', Offset(size.width - padRight + 2, padTop - 2),
        align: TextAlign.left, color: AppColors.bronze, width: padRight - 2);

    // Balken: Neu pro Tag.
    final barPaint = Paint()..color = AppColors.amber.withValues(alpha: 0.75);
    final n = points.length;
    final slot = chartW / n;
    final barW = slot * 0.6;
    for (var i = 0; i < n; i++) {
      final p = points[i];
      final h = p.newUsers / scaleNew * chartH;
      final x = padLeft + slot * i + (slot - barW) / 2;
      final y = padTop + chartH - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // X-Labels: nur erstes, mittleres und letztes Datum (gegen Overlap).
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    final indices = <int>{0, n ~/ 2, n - 1};
    for (final i in indices) {
      if (i < 0 || i >= n) continue;
      final x = padLeft + slot * i + slot / 2 - 14;
      drawText(
        fmt(points[i].day),
        Offset(x, padTop + chartH + 4),
        align: TextAlign.center,
      );
    }

    // Kumulative Linie.
    final linePaint = Paint()
      ..color = AppColors.bronze
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = points[i];
      final x = padLeft + slot * i + slot / 2;
      final y = padTop + chartH - (p.cumulative / scaleCum * chartH);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Punkte auf der Linie.
    final dotPaint = Paint()..color = AppColors.bronze;
    final dotEdge = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < n; i++) {
      final p = points[i];
      final x = padLeft + slot * i + slot / 2;
      final y = padTop + chartH - (p.cumulative / scaleCum * chartH);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      canvas.drawCircle(Offset(x, y), 2.5, dotEdge);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter old) =>
      old.points != points;
}

// ---------------------------------------------------------------------------
// Platform overview grid (6 boxes).
// ---------------------------------------------------------------------------

class _PlatformOverview extends ConsumerWidget {
  const _PlatformOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.platformOverview'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                6,
                (_) => const ShimmerBox(borderRadius: 10),
              ),
            ),
            error: (_, __) => Text(
              'admin.statsLoadShort'.tr(),
              style: AppTypography.caption(),
            ),
            data: (s) {
              final boxes = <_OverviewBoxData>[
                _OverviewBoxData(
                  icon: LucideIcons.fileText,
                  label: 'admin.lblPosts'.tr(),
                  value: '${s.posts}',
                  sub: 'admin.subActive'
                      .tr(namedArgs: {'n': '${s.activePosts}'}),
                ),
                _OverviewBoxData(
                  icon: LucideIcons.messageSquare,
                  label: 'admin.lblMessages'.tr(),
                  value: '${s.totalMessages}',
                  sub: 'admin.subConversations'
                      .tr(namedArgs: {'n': '${s.totalConversations}'}),
                ),
                _OverviewBoxData(
                  icon: LucideIcons.calendarDays,
                  label: 'admin.lblEvents'.tr(),
                  value: '${s.events}',
                  sub: 'admin.subUpcoming'
                      .tr(namedArgs: {'n': '${s.upcomingEvents}'}),
                ),
                _OverviewBoxData(
                  icon: LucideIcons.pin,
                  label: 'admin.lblBoardPosts'.tr(),
                  value: '${s.boardPosts}',
                  sub: 'admin.subActive'
                      .tr(namedArgs: {'n': '${s.activeBoardPosts}'}),
                ),
                _OverviewBoxData(
                  icon: LucideIcons.alertTriangle,
                  label: 'admin.lblCrises'.tr(),
                  value: '${s.crises}',
                  sub: 'admin.subActive'
                      .tr(namedArgs: {'n': '${s.activeCrises}'}),
                ),
                _OverviewBoxData(
                  icon: LucideIcons.building2,
                  label: 'admin.lblOrgs'.tr(),
                  value: '${s.organizations}',
                  sub: 'admin.subVerified'
                      .tr(namedArgs: {'n': '${s.verifiedOrganizations}'}),
                ),
              ];
              return GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final b in boxes) _OverviewBox(data: b),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewBoxData {
  const _OverviewBoxData({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final String label;
  final String value;
  final String sub;
}

class _OverviewBox extends StatelessWidget {
  const _OverviewBox({required this.data});
  final _OverviewBoxData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(size: 10, color: AppColors.mute),
                ),
              ),
              Text(
                data.value,
                style: AppTypography.mono(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  data.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.caption(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
