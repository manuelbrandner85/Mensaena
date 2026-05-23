import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../repositories/interactions_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/post_card.dart';
import '../../widgets/shared/stat_card.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features + mensaena-design
/// Dashboard-Home: Begruessung + 4 Stat-Cards + Schnell-Aktionen + Feed.
///
/// Pattern-Blueprint fuer alle Folgesreens:
/// - ConsumerStatefulWidget mit AsyncSnapshot via Future
/// - DashboardScaffold(body: ...) als Layout-Wrapper
/// - Datenquellen aus repositories/*
/// - Realtime-Stream auf notifications via Provider
class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  ConsumerState<DashboardHomeScreen> createState() =>
      _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  Future<_DashboardData>? _data;

  @override
  void initState() {
    super.initState();
    _data = _loadAll();
  }

  Future<_DashboardData> _loadAll() async {
    // Parallel-Fetch fuer alle Stats + Feed.
    final results = await Future.wait<dynamic>([
      ProfilesRepository.getMine(),
      NotificationsRepository.unreadCount(),
      InteractionsRepository.activeCount(),
      PostsRepository.getNearby(),
    ]);
    return _DashboardData(
      profile: results[0] as Profile?,
      unreadCount: results[1] as int,
      activeInteractions: results[2] as int,
      posts: results[3] as List<Post>,
    );
  }

  Future<void> _refresh() async {
    final fresh = _loadAll();
    setState(() => _data = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Übersicht',
      currentRoute: '/dashboard',
      body: RefreshIndicator(
        color: AppColors.amber,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardData>(
          future: _data,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final data = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _Greeting(profile: data?.profile, loading: loading),
                const SizedBox(height: 20),
                _StatsRow(data: data, loading: loading),
                const SizedBox(height: 24),
                Text(
                  'Schnell-Aktionen',
                  style: AppTypography.label(size: 10),
                ),
                const SizedBox(height: 10),
                const _QuickActions(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'In deiner Nähe',
                      style: AppTypography.display(
                        size: 20,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/dashboard/posts'),
                      child: const Text('Alle ansehen'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Feed(posts: data?.posts ?? const [], loading: loading),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Greeting ─────────────────────────────────────────────────────────────
class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile, required this.loading});
  final Profile? profile;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Guten Morgen'
        : hour < 18
            ? 'Hallo'
            : 'Guten Abend';
    final name = profile?.displayName ?? profile?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '— ${DateTime.now().toLocal().toString().substring(0, 10)}',
          style: AppTypography.label(
            size: 10,
            color: AppColors.amber,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$greeting,${name.isEmpty ? "" : "\n$name"}.',
          style: AppTypography.display(
            size: 32,
            color: AppColors.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loading
              ? 'Lade aktuelle Lage…'
              : 'Hier ist was heute in deiner Nachbarschaft los ist.',
          style: AppTypography.body(
            size: 14,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ── Stats-Row ────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data, required this.loading});
  final _DashboardData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth < 480 ? 2 : 4;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            StatCard(
              icon: LucideIcons.mapPin,
              label: 'In der Nähe',
              value: '${data?.posts.length ?? 0}',
              loading: loading,
            ),
            StatCard(
              icon: LucideIcons.bell,
              label: 'Ungelesen',
              value: '${data?.unreadCount ?? 0}',
              accent: AppColors.herzrot,
              loading: loading,
            ),
            StatCard(
              icon: LucideIcons.helpingHand,
              label: 'Interaktionen',
              value: '${data?.activeInteractions ?? 0}',
              accent: AppColors.teal,
              loading: loading,
            ),
            StatCard(
              icon: LucideIcons.star,
              label: 'Trust',
              value: '${data?.profile?.trustScore ?? 0}',
              accent: AppColors.trust,
              loading: loading,
            ),
          ],
        );
      },
    );
  }
}

// ── Quick-Actions ────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const List<({String label, IconData icon, Color accent, String route})>
      _items = [
    (
      label: 'Posten',
      icon: LucideIcons.plus,
      accent: AppColors.amber,
      route: '/dashboard/create',
    ),
    (
      label: 'Karte',
      icon: LucideIcons.map,
      accent: AppColors.teal,
      route: '/dashboard/map',
    ),
    (
      label: 'Chat',
      icon: LucideIcons.messageSquare,
      accent: AppColors.leben,
      route: '/dashboard/chat',
    ),
    (
      label: 'Krisen-SOS',
      icon: LucideIcons.alertTriangle,
      accent: AppColors.herzrot,
      route: '/dashboard/crisis',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final it = _items[i];
          return InkWell(
            onTap: () => context.go(it.route),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: it.accent.withValues(alpha: 0.12),
                border: Border.all(color: it.accent.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(it.icon, size: 18, color: it.accent),
                  Text(
                    it.label,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Feed ─────────────────────────────────────────────────────────────────
class _Feed extends StatelessWidget {
  const _Feed({required this.posts, required this.loading});
  final List<Post> posts;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    if (posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              LucideIcons.inbox,
              size: 22,
              color: AppColors.mute,
            ),
            const SizedBox(height: 8),
            Text(
              'Noch keine Beiträge in deiner Nähe.',
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sei der/die Erste:r — erstelle einen Beitrag mit dem Plus-Button.',
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: posts.map((p) => PostCard(post: p)).toList(),
    );
  }
}

// ── Data-Tuple ───────────────────────────────────────────────────────────
class _DashboardData {
  const _DashboardData({
    required this.profile,
    required this.unreadCount,
    required this.activeInteractions,
    required this.posts,
  });

  final Profile? profile;
  final int unreadCount;
  final int activeInteractions;
  final List<Post> posts;
}
