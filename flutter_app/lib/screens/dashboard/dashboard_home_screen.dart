import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../repositories/interactions_repository.dart';
import '../../repositories/matching_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/dashboard/dashboard_hero_card.dart';
import '../../widgets/dashboard/location_onboarding_modal.dart';
import '../../widgets/dashboard/safety_banners.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/location_map_view.dart';
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
  bool _locationCheckDone = false;

  @override
  void initState() {
    super.initState();
    _data = _loadAll().then((d) {
      _maybeShowLocationOnboarding(d.profile);
      return d;
    });
  }

  Future<void> _maybeShowLocationOnboarding(Profile? p) async {
    if (_locationCheckDone || p == null) return;
    if (p.latitude != null && p.longitude != null) {
      _locationCheckDone = true;
      return;
    }
    _locationCheckDone = true;
    // Warte einen Frame bis Scaffold gemounted
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => LocationOnboardingModal(
        userId: p.id,
        onSaved: (_, __, ___) {
          setState(() => _data = _loadAll());
        },
      ),
    );
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
            // Reihenfolge 1:1 zu `src/app/dashboard/page.tsx`
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // 1. Persoenliche Begruessung (Hero)
                DashboardHeroCard(
                  profile: data?.profile,
                  memberSinceDays: data?.profile == null
                      ? 0
                      : DateTime.now()
                          .difference(data!.profile!.createdAt)
                          .inDays,
                ),
                const SizedBox(height: 14),
                // 2+3. Sicherheits-/Wetter- + Lebensmittel-Warnungen
                SafetyBanners(
                  lat: data?.profile?.latitude,
                  lng: data?.profile?.longitude,
                ),
                const SizedBox(height: 14),
                if (data?.profile != null) ...[
                  // 4. Onboarding (wenn nicht abgeschlossen)
                  _OnboardingChecklist(
                    profile: data!.profile,
                    posts: data.posts,
                  ),
                  const SizedBox(height: 16),
                  // 5. Quick-Actions
                  Text('Schnell-Aktionen',
                      style: AppTypography.label(size: 10)),
                  const SizedBox(height: 8),
                  const _QuickActions(),
                  const SizedBox(height: 16),
                  // 6. Stats-Cards
                  _StatsRow(data: data, loading: loading),
                  const SizedBox(height: 16),
                  // 7. Smart-Match
                  const _SmartMatchWidget(),
                  const SizedBox(height: 16),
                  // 8. Trust-Score-Card
                  _TrustScoreCard(profile: data.profile!),
                  const SizedBox(height: 16),
                  // 9. Thanks-Received
                  _ThanksReceived(userId: data.profile!.id),
                  const SizedBox(height: 16),
                  // 10. Community-Pulse
                  _CommunityPulse(posts: data.posts),
                  const SizedBox(height: 16),
                  // 11. Activity-Feed
                  const _ActivityFeedWidget(),
                  const SizedBox(height: 16),
                  // 12. Mini-Map (nur wenn Posts vorhanden)
                  if (data.posts.isNotEmpty)
                    _MiniMapWidget(posts: data.posts.take(20).toList()),
                  const SizedBox(height: 16),
                  // 13. Weekly-Digest
                  _WeeklyDigest(profile: data.profile!),
                  const SizedBox(height: 24),
                ],
                // 14. "In deiner Naehe" — Nearby-Posts Feed
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

// ─────────────────────────────────────────────────────────────
// ActivityFeed — letzte Interaktionen
// ─────────────────────────────────────────────────────────────
class _ActivityFeedWidget extends ConsumerWidget {
  const _ActivityFeedWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(interactionsStreamProvider);
    return stream.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (interactions) {
        if (interactions.isEmpty) return const SizedBox.shrink();
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
                  const Icon(LucideIcons.activity,
                      color: AppColors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text('Aktivität',
                      style: AppTypography.label(
                          size: 10, color: AppColors.amber)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        context.go('/dashboard/interactions'),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 24),
                    ),
                    child: Text('Alle',
                        style: AppTypography.label(
                            size: 9, color: AppColors.amber)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ix in interactions.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(ix.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusLabel(ix.status),
                          style: AppTypography.body(
                              size: 12, color: AppColors.inkSoft),
                        ),
                      ),
                      Text(
                        _relativeTime(ix.createdAt),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppColors.amber;
      case 'accepted':
        return AppColors.lebenSoft;
      case 'on_way':
        return AppColors.tealSoft;
      case 'arrived':
        return AppColors.leben;
      default:
        return AppColors.mute;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Anfrage gesendet';
      case 'accepted':
        return 'Hilfe zugesagt';
      case 'on_way':
        return 'Unterwegs';
      case 'arrived':
        return 'Angekommen';
      default:
        return s;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'jetzt';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────
// OnboardingChecklist — progressive Disclosure
// ─────────────────────────────────────────────────────────────
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({required this.profile, required this.posts});
  final Profile? profile;
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (profile?.avatarUrl ?? '').isNotEmpty;
    final hasBio = (profile?.bio ?? '').isNotEmpty;
    final hasLocation = (profile?.location ?? '').isNotEmpty;
    final hasPost = posts.any(
        (p) => p.userId == profile?.id);
    final steps = [
      ('Avatar hochgeladen', hasAvatar, '/dashboard/profile'),
      ('Bio ausgefüllt', hasBio, '/dashboard/settings'),
      ('Standort gesetzt', hasLocation, '/dashboard/settings'),
      ('Erster Beitrag', hasPost, '/dashboard/create'),
    ];
    final done = steps.where((s) => s.$2).length;
    if (done == steps.length) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.12),
            AppColors.tealSoft.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkCircle,
                  color: AppColors.amber, size: 14),
              const SizedBox(width: 6),
              Text('Einstieg ($done/${steps.length})',
                  style: AppTypography.label(
                      size: 10, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: done / steps.length,
              minHeight: 4,
              backgroundColor: AppColors.elevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 10),
          for (final s in steps)
            InkWell(
              onTap: s.$2 ? null : () => context.go(s.$3),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      s.$2
                          ? LucideIcons.checkCircle2
                          : LucideIcons.circle,
                      size: 14,
                      color: s.$2 ? AppColors.lebenSoft : AppColors.mute,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.$1,
                        style: AppTypography.body(
                          size: 13,
                          color: s.$2 ? AppColors.mute : AppColors.ink,
                          weight: s.$2
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!s.$2)
                      const Icon(LucideIcons.chevronRight,
                          size: 14, color: AppColors.amber),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ThanksReceived — letzte Trust-Ratings die der User erhalten hat
// ─────────────────────────────────────────────────────────────
class _ThanksReceived extends ConsumerWidget {
  const _ThanksReceived({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRatings(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lebenSoft.withValues(alpha: 0.08),
            border: Border.all(
                color: AppColors.lebenSoft.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.heart,
                      color: AppColors.lebenSoft, size: 14),
                  const SizedBox(width: 6),
                  Text('Dank erhalten',
                      style: AppTypography.label(
                          size: 10, color: AppColors.lebenSoft)),
                ],
              ),
              const SizedBox(height: 8),
              for (final r in list.take(2))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0;
                              i < ((r['stars'] as num?)?.toInt() ?? 0);
                              i++)
                            const Icon(LucideIcons.star,
                                size: 11, color: AppColors.amber),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (r['comment'] as String?) ?? '—',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.inkSoft,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRatings() async {
    try {
      final rows = await sb
          .from('trust_ratings')
          .select()
          .eq('rated_user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SmartMatch — Top 3 Match-Vorschlaege
// ─────────────────────────────────────────────────────────────
class _SmartMatchWidget extends ConsumerWidget {
  const _SmartMatchWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchingListProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (matches) {
        final pending =
            matches.where((m) => m.status == 'pending').take(3).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.go('/dashboard/matching'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tealSoft.withValues(alpha: 0.12),
                  AppColors.amber.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                  color: AppColors.tealSoft.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles,
                        color: AppColors.tealSoft, size: 14),
                    const SizedBox(width: 6),
                    Text('Smart-Match',
                        style: AppTypography.label(
                            size: 10, color: AppColors.tealSoft)),
                    const Spacer(),
                    Text('${pending.length} offen',
                        style: AppTypography.label(
                            size: 9, color: AppColors.mute)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final m in pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.teal.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(m.matchScore * 100).toInt()}%',
                            style: AppTypography.mono(
                                size: 10, color: AppColors.tealSoft),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.requestPost.title.isNotEmpty
                                ? m.requestPost.title
                                : m.offerPost.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.ink),
                          ),
                        ),
                        if (m.distanceKm != null)
                          Text('${m.distanceKm!.toStringAsFixed(0)} km',
                              style: AppTypography.caption()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MiniMapWidget — kleine Karte mit Posts in der Naehe
// ─────────────────────────────────────────────────────────────
class _MiniMapWidget extends StatelessWidget {
  const _MiniMapWidget({required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    color: AppColors.amber, size: 14),
                const SizedBox(width: 6),
                Text('Karte',
                    style: AppTypography.label(
                        size: 10, color: AppColors.amber)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/dashboard/map'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 24),
                  ),
                  child: Text('Vollbild',
                      style: AppTypography.label(
                          size: 9, color: AppColors.amber)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11)),
              child: LocationMapView(
                markers: [
                  for (final p in posts)
                    MapMarkerData(
                      id: p.id,
                      lat: p.latitude,
                      lng: p.longitude,
                      color: AppColors.amber,
                      title: p.title,
                    ),
                ],
                initialZoom: 9,
                onMarkerTap: (m) =>
                    context.go('/dashboard/posts/${m.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WeeklyDigest — Aktivitaet der letzten 7 Tage
// ─────────────────────────────────────────────────────────────
class _WeeklyDigest extends StatefulWidget {
  const _WeeklyDigest({required this.profile});
  final Profile profile;

  @override
  State<_WeeklyDigest> createState() => _WeeklyDigestState();
}

class _WeeklyDigestState extends State<_WeeklyDigest> {
  late Future<_DigestData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DigestData> _load() async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    try {
      final results = await Future.wait([
        sb
            .from('posts')
            .select('id')
            .eq('user_id', widget.profile.id)
            .gte('created_at', since),
        sb
            .from('interactions')
            .select('id')
            .or('helper_id.eq.${widget.profile.id},helped_id.eq.${widget.profile.id}')
            .gte('created_at', since),
        sb
            .from('messages')
            .select('id')
            .eq('sender_id', widget.profile.id)
            .gte('created_at', since),
      ]);
      return _DigestData(
        posts: (results[0] as List).length,
        interactions: (results[1] as List).length,
        messages: (results[2] as List).length,
      );
    } catch (_) {
      return const _DigestData(posts: 0, interactions: 0, messages: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DigestData>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data ?? const _DigestData(
          posts: 0,
          interactions: 0,
          messages: 0,
        );
        if (d.posts + d.interactions + d.messages == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bronze.withValues(alpha: 0.10),
            border: Border.all(
                color: AppColors.bronze.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendar,
                      color: AppColors.bronze, size: 14),
                  const SizedBox(width: 6),
                  Text('Diese Woche',
                      style: AppTypography.label(
                          size: 10, color: AppColors.bronzeSoft)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _digestStat('${d.posts}',
                          'Beiträge', LucideIcons.fileText)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _digestStat('${d.interactions}',
                          'Hilfen', LucideIcons.helpingHand)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _digestStat('${d.messages}',
                          'Nachrichten', LucideIcons.messageCircle)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _digestStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: AppColors.bronzeSoft),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.mono(size: 18, color: AppColors.ink)),
          Text(label,
              style: AppTypography.label(
                  size: 8, color: AppColors.bronzeSoft)),
        ],
      ),
    );
  }
}

class _DigestData {
  const _DigestData({
    required this.posts,
    required this.interactions,
    required this.messages,
  });
  final int posts;
  final int interactions;
  final int messages;
}
