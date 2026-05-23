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
                const SizedBox(height: 16),
                if (data?.profile != null)
                  _TrustScoreCard(profile: data!.profile!),
                const SizedBox(height: 20),
                _CommunityPulse(posts: data?.posts ?? const []),
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

// ─────────────────────────────────────────────────────────────
// TrustScore-Card — Pendant zu TrustScoreWidget aus Dashboard
// ─────────────────────────────────────────────────────────────
class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({required this.profile});
  final Profile profile;

  String _levelLabel(double score) {
    if (score >= 4.5) return 'Legende';
    if (score >= 4.0) return 'Vorbild';
    if (score >= 3.5) return 'Erfahren';
    if (score >= 3.0) return 'Etabliert';
    if (score >= 2.0) return 'Aufsteigend';
    return 'Neu';
  }

  @override
  Widget build(BuildContext context) {
    final score = profile.trustScore.toDouble();
    final count = profile.trustScoreCount;
    final level = _levelLabel(score);
    final ratio = (score / 5).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => context.go('/dashboard/profile'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.trust.withValues(alpha: 0.16),
              AppColors.amber.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.trust.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.trust.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.shieldCheck,
                  color: AppColors.trust, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Vertrauen',
                          style: AppTypography.label(
                              size: 10, color: AppColors.trust)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.trust.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(level,
                            style: AppTypography.label(
                                size: 8, color: AppColors.trustSoft)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(score.toStringAsFixed(1),
                          style: AppTypography.mono(
                            size: 22,
                            color: AppColors.ink,
                          )),
                      Text(' / 5',
                          style: AppTypography.label(
                              size: 10, color: AppColors.mute)),
                      const SizedBox(width: 8),
                      Text('($count Bew.)',
                          style: AppTypography.caption()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      backgroundColor: AppColors.elevated,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.trust),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Community-Pulse — Live-Aktivitaet
// ─────────────────────────────────────────────────────────────
class _CommunityPulse extends StatelessWidget {
  const _CommunityPulse({required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final last24h = posts.where((p) {
      return today.difference(p.createdAt).inHours < 24;
    }).length;
    final helpRequests =
        posts.where((p) => p.type == 'help_request').length;
    final helpOffers =
        posts.where((p) => p.type == 'help_offered').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.leben,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('Community-Puls',
                  style: AppTypography.label(
                      size: 10, color: AppColors.lebenSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PulseStat(
                    label: 'Neue Posts (24h)',
                    value: '$last24h',
                    icon: LucideIcons.trendingUp,
                    color: AppColors.amber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseStat(
                    label: 'Hilfe gesucht',
                    value: '$helpRequests',
                    icon: LucideIcons.heart,
                    color: AppColors.herzrotWarm),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseStat(
                    label: 'Hilfe da',
                    value: '$helpOffers',
                    icon: LucideIcons.helpingHand,
                    color: AppColors.lebenSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.mono(size: 18, color: AppColors.ink)),
          Text(label,
              style: AppTypography.label(size: 8, color: color)),
        ],
      ),
    );
  }
}
