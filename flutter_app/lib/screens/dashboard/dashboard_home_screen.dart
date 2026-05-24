import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
import '../../services/weather_service.dart';
import '../../widgets/dashboard/dashboard_hero_card.dart';
import '../../widgets/dashboard/location_onboarding_modal.dart';
import '../../widgets/dashboard/onboarding_tour.dart';
import '../../widgets/dashboard/safety_banners.dart';
import '../../widgets/dashboard/widget_grid_settings.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OnboardingTour.maybeShow(context);
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
    final cfg = ref.watch(dashboardWidgetConfigProvider).asData?.value ??
        DashboardWidgetConfig.defaultConfig;
    bool show(String id) => cfg.visible.contains(id);
    return DashboardScaffold(
      title: 'home.dashboardTitle'.tr(),
      currentRoute: '/dashboard',
      fab: FloatingActionButton.small(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.bronze,
        onPressed: () => WidgetSettingsSheet.show(context),
        tooltip: 'home.configureWidgets'.tr(),
        child: const Icon(LucideIcons.settings, size: 16),
      ),
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
                if (show('hero')) ...[
                  DashboardHeroCard(
                    profile: data?.profile,
                    memberSinceDays: data?.profile == null
                        ? 0
                        : DateTime.now()
                            .difference(data!.profile!.createdAt)
                            .inDays,
                  ),
                  const SizedBox(height: 14),
                ],
                // 2+3. Sicherheits-/Wetter- + Lebensmittel-Warnungen
                if (show('safety')) ...[
                  SafetyBanners(
                    lat: data?.profile?.latitude,
                    lng: data?.profile?.longitude,
                  ),
                  const SizedBox(height: 14),
                ],
                if (data?.profile != null) ...[
                  if (show('onboarding')) ...[
                    _OnboardingChecklist(
                      profile: data!.profile,
                      posts: data.posts,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (show('quick_actions')) ...[
                    Text('home.quickActions'.tr(),
                        style: AppTypography.label(size: 10)),
                    const SizedBox(height: 8),
                    const _QuickActions(),
                    const SizedBox(height: 16),
                  ],
                  if (show('unread_messages')) ...[
                    const _UnreadMessagesWidget(),
                    const SizedBox(height: 16),
                  ],
                  if (show('stats')) ...[
                    _StatsRow(data: data, loading: loading),
                    const SizedBox(height: 16),
                  ],
                  if (show('smart_match')) ...[
                    const _SmartMatchWidget(),
                    const SizedBox(height: 16),
                  ],
                  if (show('weekly_challenge')) ...[
                    const _WeeklyChallengeHighlight(),
                    const SizedBox(height: 16),
                  ],
                  if (show('rating_prompt')) ...[
                    _RatingPromptBanner(userId: data!.profile!.id),
                    const SizedBox(height: 16),
                  ],
                  if (show('trust_score')) ...[
                    _TrustScoreCard(profile: data!.profile!),
                    const SizedBox(height: 16),
                  ],
                  if (show('thanks')) ...[
                    _ThanksReceived(userId: data!.profile!.id),
                    const SizedBox(height: 16),
                  ],
                  if (show('weather')) ...[
                    if (data!.profile?.latitude != null &&
                        data.profile?.longitude != null)
                      _WeatherWidget(
                        lat: data.profile!.latitude!,
                        lng: data.profile!.longitude!,
                      )
                    else
                      _LocationCta(
                        icon: '🌤️',
                        title: 'home.weatherUnlockTitle'.tr(),
                        subtitle: 'home.weatherUnlockBody'.tr(),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (show('holiday_badge') &&
                      data!.profile?.latitude != null &&
                      data.profile?.longitude != null) ...[
                    _HolidayBadge(
                      lat: data.profile!.latitude!,
                      lng: data.profile!.longitude!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (show('community_pulse')) ...[
                    _CommunityPulse(posts: data!.posts),
                    const SizedBox(height: 16),
                  ],
                  if (show('activity_feed')) ...[
                    const _ActivityFeedWidget(),
                    const SizedBox(height: 16),
                  ],
                  if (show('mini_map')) ...[
                    if (data!.posts.isNotEmpty)
                      _MiniMapWidget(posts: data.posts.take(20).toList())
                    else
                      const _MapEmptyTile(),
                    const SizedBox(height: 16),
                  ],
                  if (show('success_story')) ...[
                    const _SuccessStoryCard(),
                    const SizedBox(height: 16),
                  ],
                  if (show('bot_tip')) ...[
                    const _BotTipCard(),
                    const SizedBox(height: 16),
                  ],
                  if (show('weekly_digest')) ...[
                    _WeeklyDigest(profile: data!.profile!),
                    const SizedBox(height: 24),
                  ],
                ],
                // 14. "In deiner Naehe" — Nearby-Posts Feed
                Row(
                  children: [
                    Text(
                      'home.nearbyTitle'.tr(),
                      style: AppTypography.display(
                        size: 20,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/dashboard/posts'),
                      child: Text('home.viewAll'.tr()),
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

// ── Stats-Row — animierte Counter, Cinema-Bronze-Frame ───────────────────
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
            _AnimatedStatCard(
              icon: LucideIcons.mapPin,
              label: 'home.statNearby'.tr(),
              value: data?.posts.length ?? 0,
              accent: AppColors.bronze,
              loading: loading,
            ),
            _AnimatedStatCard(
              icon: LucideIcons.bell,
              label: 'home.statUnread'.tr(),
              value: data?.unreadCount ?? 0,
              accent: AppColors.herzrot,
              loading: loading,
            ),
            _AnimatedStatCard(
              icon: LucideIcons.helpingHand,
              label: 'home.statInteractions'.tr(),
              value: data?.activeInteractions ?? 0,
              accent: AppColors.teal,
              loading: loading,
            ),
            _AnimatedStatCard(
              icon: LucideIcons.star,
              label: 'home.statTrust'.tr(),
              value: data?.profile?.trustScore ?? 0,
              accent: AppColors.trust,
              loading: loading,
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  const _AnimatedStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return StatCard(
        icon: icon,
        label: label,
        value: '—',
        accent: accent,
        loading: true,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return StatCard(
          icon: icon,
          label: label,
          value: '${v.round()}',
          accent: accent,
        );
      },
    );
  }
}

// ── Quick-Actions — prominenter, größere Touch-Ziele ─────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _items = <({
    String i18n,
    IconData icon,
    Color accent,
    String route,
  })>[
    (
      i18n: 'home.qaPost',
      icon: LucideIcons.plus,
      accent: AppColors.amber,
      route: '/dashboard/create',
    ),
    (
      i18n: 'home.qaMap',
      icon: LucideIcons.map,
      accent: AppColors.teal,
      route: '/dashboard/map',
    ),
    (
      i18n: 'home.qaChat',
      icon: LucideIcons.messageSquare,
      accent: AppColors.leben,
      route: '/dashboard/chat',
    ),
    (
      i18n: 'home.qaSos',
      icon: LucideIcons.alertTriangle,
      accent: AppColors.herzrot,
      route: '/dashboard/crisis',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final it = _items[i];
          final isSos = it.route == '/dashboard/crisis';
          return InkWell(
            onTap: () => context.go(it.route),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 108,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    it.accent.withValues(alpha: 0.20),
                    it.accent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: it.accent.withValues(alpha: isSos ? 0.7 : 0.45),
                  width: isSos ? 1.6 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSos
                    ? [
                        BoxShadow(
                          color: it.accent.withValues(alpha: 0.22),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: it.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(it.icon, size: 18, color: it.accent),
                  ),
                  Text(
                    it.i18n.tr(),
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
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
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.5),
              AppColors.bronze.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border:
              Border.all(color: AppColors.bronze.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.inbox,
                  size: 22, color: AppColors.bronze),
            ),
            const SizedBox(height: 12),
            Text(
              'home.feedEmptyTitle'.tr(),
              style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'home.feedEmptyBody'.tr(),
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  textStyle: AppTypography.body(
                      size: 14, weight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text('home.feedEmptyCta'.tr()),
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
                      Text('home.trust'.tr(),
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
              Text('home.communityPulse'.tr(),
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
                  Text('home.activity'.tr(),
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
                    child: Text('home.all'.tr(),
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
              Text(
                  'home.onboardingStart'.tr(namedArgs: {
                    'done': '$done',
                    'total': '${steps.length}',
                  }),
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
                  Text('home.thanksReceived'.tr(),
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
          .eq('rated_id', userId)
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
                    Text('home.smartMatch'.tr(),
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
                Text('home.map'.tr(),
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
                  child: Text('home.fullscreen'.tr(),
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
                  Text('home.thisWeek'.tr(),
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

// ═════════════════════════════════════════════════════════════════
// UnreadMessagesWidget — 1:1 zu Web src/app/dashboard/components/UnreadMessages.tsx
// ═════════════════════════════════════════════════════════════════
class _UnreadMessagesWidget extends StatefulWidget {
  const _UnreadMessagesWidget();

  @override
  State<_UnreadMessagesWidget> createState() => _UnreadMessagesWidgetState();
}

class _UnreadMessagesWidgetState extends State<_UnreadMessagesWidget> {
  late Future<List<_UnreadMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_UnreadMessage>> _load() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      // Eigene Conversation-Memberships + last_read_at holen
      final memberships = await sb
          .from('conversation_members')
          .select('conversation_id, last_read_at')
          .eq('user_id', uid);
      final memList = (memberships as List).whereType<Map<String, dynamic>>();
      if (memList.isEmpty) return const [];

      final result = <_UnreadMessage>[];
      for (final m in memList) {
        final convId = m['conversation_id'] as String?;
        if (convId == null) continue;
        final lastRead = m['last_read_at'] != null
            ? DateTime.tryParse(m['last_read_at'] as String)
            : null;

        // Letzte Nachricht der Conversation
        final msgs = await sb
            .from('messages')
            .select('id, content, sender_id, created_at')
            .eq('conversation_id', convId)
            .neq('sender_id', uid)
            .order('created_at', ascending: false)
            .limit(20);
        final msgList = (msgs as List).whereType<Map<String, dynamic>>();
        if (msgList.isEmpty) continue;

        final unread = msgList.where((row) {
          final createdAt =
              DateTime.tryParse(row['created_at'] as String? ?? '');
          if (createdAt == null) return false;
          return lastRead == null || createdAt.isAfter(lastRead);
        }).toList();
        if (unread.isEmpty) continue;

        final newest = unread.first;
        final senderId = newest['sender_id'] as String?;
        String senderName = 'Nachbar:in';
        String? senderAvatar;
        if (senderId != null) {
          try {
            final p = await sb
                .from('profiles')
                .select('name, display_name, avatar_url')
                .eq('id', senderId)
                .maybeSingle();
            if (p != null) {
              senderName = (p['display_name'] as String?) ??
                  (p['name'] as String?) ??
                  senderName;
              senderAvatar = p['avatar_url'] as String?;
            }
          } catch (_) {}
        }
        result.add(_UnreadMessage(
          conversationId: convId,
          senderName: senderName,
          senderAvatar: senderAvatar,
          lastText: (newest['content'] as String?) ?? '',
          timestamp: DateTime.tryParse(newest['created_at'] as String? ?? '') ??
              DateTime.now(),
          unreadCount: unread.length,
        ));
      }
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result.take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'jetzt';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_UnreadMessage>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <_UnreadMessage>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final total = list.fold<int>(0, (s, m) => s + m.unreadCount);
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
                  const Icon(LucideIcons.messageCircle,
                      color: AppColors.herzrotWarm, size: 14),
                  const SizedBox(width: 6),
                  Text('home.unreadMessages'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.herzrotWarm)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$total',
                        style: AppTypography.mono(
                            size: 10, color: AppColors.herzrotWarm)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/dashboard/chat'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 24),
                    ),
                    child: Text('home.allArrow'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.bronze)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final m in list)
                InkWell(
                  onTap: () => context
                      .go('/dashboard/chat?conv=${m.conversationId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.elevated,
                          backgroundImage: (m.senderAvatar != null &&
                                  m.senderAvatar!.isNotEmpty)
                              ? NetworkImage(m.senderAvatar!)
                              : null,
                          child: (m.senderAvatar == null ||
                                  m.senderAvatar!.isEmpty)
                              ? Text(
                                  m.senderName.isNotEmpty
                                      ? m.senderName[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.mono(
                                      size: 12, color: AppColors.bronze),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 13,
                                    color: AppColors.ink,
                                    weight: FontWeight.w600),
                              ),
                              Text(
                                m.lastText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 11, color: AppColors.mute),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_ago(m.timestamp),
                                style: AppTypography.caption()),
                            const SizedBox(height: 2),
                            if (m.unreadCount > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.herzrot,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('${m.unreadCount}',
                                    style: AppTypography.mono(
                                        size: 9, color: AppColors.ink)),
                              )
                            else
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.herzrot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UnreadMessage {
  const _UnreadMessage({
    required this.conversationId,
    required this.senderName,
    required this.senderAvatar,
    required this.lastText,
    required this.timestamp,
    required this.unreadCount,
  });
  final String conversationId;
  final String senderName;
  final String? senderAvatar;
  final String lastText;
  final DateTime timestamp;
  final int unreadCount;
}

// ═════════════════════════════════════════════════════════════════
// WeeklyChallengeHighlight — 1:1 zu Web WeeklyChallengeHighlight.tsx
// ═════════════════════════════════════════════════════════════════
class _WeeklyChallengeHighlight extends StatefulWidget {
  const _WeeklyChallengeHighlight();

  @override
  State<_WeeklyChallengeHighlight> createState() =>
      _WeeklyChallengeHighlightState();
}

class _WeeklyChallengeHighlightState extends State<_WeeklyChallengeHighlight> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Mo, 7=So
      final monday = now.subtract(Duration(days: weekday - 1));
      final weekOf =
          '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final rows = await sb
          .from('challenges')
          .select(
              'id, title, description, category, difficulty, points, participant_count')
          .eq('is_weekly', true)
          .eq('week_of', weekOf)
          .order('points', ascending: false)
          .limit(3);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.go('/dashboard/challenges'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bronze.withValues(alpha: 0.18),
                  AppColors.amber.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles,
                        color: AppColors.bronze, size: 14),
                    const SizedBox(width: 6),
                    Text('home.challengesThisWeek'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.bronzeSoft)),
                    const Spacer(),
                    Text('home.allArrow'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.bronze)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('home.weeklyImpulses'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.mute)),
                const SizedBox(height: 10),
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['title'] as String?) ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                      size: 13,
                                      color: AppColors.ink,
                                      weight: FontWeight.w600),
                                ),
                                if ((c['description'] as String?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c['description'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                        size: 11,
                                        color: AppColors.mute),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.trophy,
                                    size: 10, color: AppColors.amber),
                                const SizedBox(width: 3),
                                Text('${c['points'] ?? 0}',
                                    style: AppTypography.mono(
                                        size: 10,
                                        color: AppColors.amberWarm)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

// ═════════════════════════════════════════════════════════════════
// RatingPromptBanner — 1:1 zu Web RatingPromptBanner.tsx
// Liest offene Ratings: trust_ratings_pending oder interactions mit
// status='completed' und rated_by_me=false.
// ═════════════════════════════════════════════════════════════════
class _RatingPromptBanner extends StatefulWidget {
  const _RatingPromptBanner({required this.userId});
  final String userId;

  @override
  State<_RatingPromptBanner> createState() => _RatingPromptBannerState();
}

class _RatingPromptBannerState extends State<_RatingPromptBanner> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      // Versuch 1: RPC get_pending_ratings (existiert in Web)
      try {
        final res = await sb
            .rpc<dynamic>('get_pending_ratings', params: {'p_user_id': widget.userId});
        if (res is List) {
          return res.whereType<Map<String, dynamic>>().toList();
        }
      } catch (_) {}
      // Fallback: interactions mit status='completed' wo aktueller User Helfer/Helped war
      final rows = await sb
          .from('interactions')
          .select('id, helper_id, helped_id, post_id, status, completed_at')
          .or('helper_id.eq.${widget.userId},helped_id.eq.${widget.userId}')
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(5);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final count = list.length;
        final first = list.first;
        final partnerName =
            (first['partner_name'] as String?) ?? 'deinen Nachbarn';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            border:
                Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.star,
                    color: AppColors.amber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'Du hast eine offene Bewertung'
                          : 'Du hast $count offene Bewertungen',
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bewerte $partnerName für die Zusammenarbeit.',
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/dashboard/interactions'),
                        icon: const Icon(LucideIcons.star, size: 14),
                        label: Text('home.rateNow'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.voidColor,
                          textStyle: AppTypography.body(
                              size: 12, weight: FontWeight.w600),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Später erinnern',
                icon:
                    const Icon(LucideIcons.x, size: 14, color: AppColors.mute),
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// WeatherWidget — 1:1 zu Web src/app/dashboard/components/WeatherWidget.tsx
// ═════════════════════════════════════════════════════════════════
class _WeatherWidget extends StatefulWidget {
  const _WeatherWidget({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  State<_WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<_WeatherWidget> {
  Future<List<WeatherDay>>? _future;

  @override
  void initState() {
    super.initState();
    _future = WeatherService.forecast(
      latitude: widget.lat,
      longitude: widget.lng,
      days: 1,
    );
  }

  String _tip(WeatherDay d) {
    if (d.code >= 95) return 'Gewitter – drinnen bleiben und Nachbarn informieren. ⚡';
    if (d.code >= 71 && d.code <= 77) {
      return 'Schnee – Gehwege freihalten! Hilf älteren Nachbarn. 🏠';
    }
    if (d.tempMin < 0) return 'Frost! Hilf älteren Nachbarn beim Räumen. 🧤';
    if (d.code >= 61 && d.code <= 67) {
      return 'Hast du einen Regenschirm übrig? Deine Nachbarn danken es dir. ☂️';
    }
    if (d.code == 45 || d.code == 48) {
      return 'Nebel – Vorsicht beim Radfahren und zu Fuß. 🚶';
    }
    if (d.tempMax >= 30) return 'Heiß! Biete deinen Nachbarn etwas Wasser an. 💧';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WeatherDay>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <WeatherDay>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final d = list.first;
        final tip = _tip(d);
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
                  Text(d.emoji,
                      style: const TextStyle(fontSize: 28, height: 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('home.currentWeather'.tr(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.mute)),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                weight: FontWeight.w700),
                            children: [
                              TextSpan(
                                  text:
                                      '${d.tempMax.round()}° / ${d.tempMin.round()}°'),
                              TextSpan(
                                text: '  ${d.label}',
                                style: AppTypography.body(
                                    size: 12,
                                    color: AppColors.mute,
                                    weight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('home.weatherSource'.tr(),
                      style: AppTypography.caption()),
                ],
              ),
              if (tip.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bronze.withValues(alpha: 0.08),
                    border: Border.all(
                        color: AppColors.bronze.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tip,
                    style: AppTypography.body(
                        size: 11, color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// HolidayBadge — 1:1 zu Web HolidayBadge.tsx
// Holt Feiertage via Nager.Date API (kostenlos, kein Key).
// ═════════════════════════════════════════════════════════════════
class _HolidayBadge extends StatefulWidget {
  const _HolidayBadge({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  State<_HolidayBadge> createState() => _HolidayBadgeState();
}

class _HolidayBadgeState extends State<_HolidayBadge> {
  Future<_HolidayStatus?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HolidayStatus?> _load() async {
    try {
      final year = DateTime.now().year;
      // Deutschland: Nager.Date PublicHolidays
      final uri = Uri.https(
          'date.nager.at', '/api/v3/PublicHolidays/$year/DE');
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      _HolidayStatus? best;
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final dateStr = raw['date'] as String?;
        if (dateStr == null) continue;
        final d = DateTime.tryParse(dateStr);
        if (d == null) continue;
        final daysDiff = d.difference(todayStart).inDays;
        if (daysDiff < 0) continue;
        if (daysDiff > 60) continue;
        final name = (raw['localName'] as String?) ??
            (raw['name'] as String?) ??
            'Feiertag';
        if (best == null || daysDiff < best.days) {
          best = _HolidayStatus(name: name, date: d, days: daysDiff);
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  String _emoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('weihnachten') || n.contains('christ')) return '🎄';
    if (n.contains('silvester') || n.contains('neujahr')) return '🎆';
    if (n.contains('ostern') || n.contains('karfreitag')) return '🐰';
    if (n.contains('pfingst')) return '🕊️';
    if (n.contains('himmelfahrt')) return '☁️';
    if (n.contains('mai')) return '🌷';
    if (n.contains('einheit') || n.contains('national')) return '🇩🇪';
    if (n.contains('reformation')) return '✝️';
    if (n.contains('allerheilig')) return '🕯️';
    return '🎉';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HolidayStatus?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final emoji = _emoji(s.name);
        final headline = s.days == 0
            ? 'Heute ist ${s.name}'
            : s.days == 1
                ? 'Morgen ist ${s.name}'
                : 'Nächster Feiertag: ${s.name}';
        final subtitle = s.days == 0
            ? 'Schönen Feiertag! 🎉'
            : s.days == 1
                ? 'Morgen frei – plane jetzt etwas mit deinen Nachbar:innen.'
                : '${s.date.day.toString().padLeft(2, '0')}.${s.date.month.toString().padLeft(2, '0')}.${s.date.year} · in ${s.days} Tag${s.days == 1 ? '' : 'en'}';
        return InkWell(
          onTap: () => context.go('/dashboard/events'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bronze.withValues(alpha: 0.16),
                  AppColors.herzrotWarm.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bronze.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    s.days == 0
                        ? LucideIcons.partyPopper
                        : LucideIcons.calendar,
                    color: AppColors.bronze,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(
                                  fontSize: 18, height: 1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft),
                      ),
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

class _HolidayStatus {
  const _HolidayStatus({
    required this.name,
    required this.date,
    required this.days,
  });
  final String name;
  final DateTime date;
  final int days;
}

// ═════════════════════════════════════════════════════════════════
// SuccessStoryCard — 1:1 zu Web SuccessStoryCard.tsx
// ═════════════════════════════════════════════════════════════════
class _SuccessStoryCard extends StatefulWidget {
  const _SuccessStoryCard();

  @override
  State<_SuccessStoryCard> createState() => _SuccessStoryCardState();
}

class _SuccessStoryCardState extends State<_SuccessStoryCard> {
  Future<Map<String, dynamic>?>? _future;
  bool _rotating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      List<Map<String, dynamic>> data;
      try {
        final rows = await sb
            .from('success_stories')
            .select(
                'id, title, body, image_url, profiles!success_stories_author_id_fkey(name, location)')
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(20);
        data = (rows as List).whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        // Fallback ohne image_url
        final rows = await sb
            .from('success_stories')
            .select(
                'id, title, body, profiles!success_stories_author_id_fkey(name, location)')
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(20);
        data = (rows as List).whereType<Map<String, dynamic>>().toList();
      }
      if (data.isEmpty) return null;
      data.shuffle();
      return data.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _rotating = true;
      _future = _load();
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _rotating = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final title = (s['title'] as String?) ?? '';
        final body = (s['body'] as String?) ?? '';
        final image = s['image_url'] as String?;
        final profileRaw = s['profiles'];
        Map<String, dynamic>? profile;
        if (profileRaw is Map<String, dynamic>) {
          profile = profileRaw;
        } else if (profileRaw is List && profileRaw.isNotEmpty) {
          final f = profileRaw.first;
          if (f is Map<String, dynamic>) profile = f;
        }
        final author = profile?['name'] as String?;
        final loc = profile?['location'] as String?;
        final excerpt = body.length > 180
            ? '${body.substring(0, 180).trimRight()}…'
            : body;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.bronze.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.bookOpen,
                              size: 14, color: AppColors.bronze),
                        ),
                        const SizedBox(width: 8),
                        Text('home.successStory'.tr(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.bronzeSoft)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Andere Geschichte',
                          onPressed: _refresh,
                          icon: AnimatedRotation(
                            turns: _rotating ? 0.5 : 0,
                            duration: const Duration(milliseconds: 500),
                            child: const Icon(LucideIcons.refreshCw,
                                size: 14, color: AppColors.mute),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                          height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '„$excerpt"',
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.5),
                    ),
                    if (author != null && author.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '— $author${loc != null && loc.isNotEmpty ? ', $loc' : ''}',
                        style: AppTypography.caption(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// BotTipCard — 1:1 zu Web BotTipCard.tsx
// ═════════════════════════════════════════════════════════════════
class _BotTipCard extends StatefulWidget {
  const _BotTipCard();

  @override
  State<_BotTipCard> createState() => _BotTipCardState();
}

class _BotTipCardState extends State<_BotTipCard> {
  static const _tips = <String>[
    'Hast du heute schon die Karte gecheckt? Vielleicht braucht jemand in deiner Nähe Hilfe!',
    'Ein Lächeln kostet nichts – schreib deinem Nachbarn eine nette Nachricht.',
    'Teile deine Fähigkeiten! Im Skill-Netzwerk kannst du anderen helfen und Neues lernen.',
    'Kleine Gesten, große Wirkung: Biete Einkaufshilfe in deiner Nachbarschaft an.',
    'Kennst du die Zeitbank? Tausche Zeit statt Geld mit deinen Nachbarn!',
  ];
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = _tips[DateTime.now().day % _tips.length];
  }

  void _next() {
    setState(() {
      final idx = (_tips.indexOf(_current) + 1) % _tips.length;
      _current = _tips[idx];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.12),
            AppColors.amber.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.sparkles,
                    size: 14, color: AppColors.bronze),
              ),
              const SizedBox(width: 8),
              Text('home.botName'.tr(),
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              const Icon(LucideIcons.lightbulb,
                  size: 14, color: AppColors.bronze),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _current,
            style: AppTypography.body(
                size: 13, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => context.go('/dashboard/chat'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 24),
                ),
                child: Text('home.chatWithBot'.tr(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.bronze)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _next,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 24),
                ),
                icon: const Icon(LucideIcons.refreshCw,
                    size: 11, color: AppColors.bronze),
                label: Text('home.nextTip'.tr(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.bronze)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fallback-Widgets — garantieren dass alle Dashboard-Slots etwas zeigen ─

class _LocationCta extends StatelessWidget {
  const _LocationCta({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/settings'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}

class _MapEmptyTile extends StatelessWidget {
  const _MapEmptyTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/map'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.bronze.withValues(alpha: 0.15),
              AppColors.amber.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.map,
                size: 36, color: AppColors.bronze),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('home.exploreMap'.tr(),
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    'In deiner Nähe ist noch nichts los — schaue auf der Karte, was es weiter draußen gibt.',
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
