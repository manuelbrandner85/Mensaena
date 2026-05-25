/// SKILL: mensaena-features
/// Dashboard-Home (Phase-3 Refactor) — Layout + Widget-Orchestration.
///
/// Klein und uebersichtlich (<300 Zeilen). Alle Widgets leben in
/// `widgets/dashboard/*`. Reihenfolge + Sichtbarkeit kommt aus
/// `WidgetGridConfigService` (Phase-2 Provider).
///
/// V14 Horizontal Sections:
///   * Stats-Row → PageView+Dots (intern in StatsRow gekapselt).
///   * Trust + Weather + Holiday → horizontaler Scroll mit Section-Header.
///   * SmartMatch + Challenge → Stacked Cards mit Swipe (PageView).
///   * NearbyPosts bleibt vertikaler Feed.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/post.dart';
import '../../../models/profile.dart';
import '../../../repositories/interactions_repository.dart';
import '../../../repositories/notifications_repository.dart';
import '../../../repositories/posts_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../widgets/dashboard/activity_feed_widget.dart';
import '../../../widgets/dashboard/books_widget.dart';
import '../../../widgets/dashboard/bot_tip_card.dart';
import '../../../widgets/dashboard/community_pulse.dart';
import '../../../widgets/dashboard/daily_quote_widget.dart';
import '../../../widgets/dashboard/health_widget.dart';
import '../../../widgets/dashboard/mood_chart_widget.dart';
import '../../../widgets/dashboard/nasa_apod_widget.dart';
import '../../../widgets/dashboard/on_this_day_widget.dart';
import '../../../widgets/dashboard/gratitude_widget.dart';
import '../../../widgets/dashboard/karma_widget.dart';
import '../../../widgets/dashboard/streak_widget.dart';
import '../../../widgets/dashboard/weekly_recap_widget.dart';
import '../../../widgets/dashboard/sun_widget.dart';
import '../../../widgets/dashboard/traffic_info_widget.dart';
import '../../../widgets/dashboard/dashboard_hero_card.dart';
import '../../../widgets/dashboard/holiday_badge.dart';
import '../../../widgets/dashboard/location_onboarding_modal.dart';
import '../../../widgets/dashboard/mini_map_widget.dart';
import '../../../widgets/dashboard/onboarding_checklist.dart';
import '../../../widgets/dashboard/onboarding_tour.dart';
import '../../../widgets/dashboard/quick_actions.dart';
import '../../../widgets/dashboard/rating_prompt_banner.dart';
import '../../../widgets/dashboard/safety_banners.dart';
import '../../../widgets/dashboard/smart_match_widget.dart';
import '../../../widgets/dashboard/stats_row.dart';
import '../../../widgets/dashboard/success_story_card.dart';
import '../../../widgets/dashboard/thanks_received.dart';
import '../../../widgets/dashboard/trust_score_card.dart';
import '../../../widgets/dashboard/unread_messages_widget.dart';
import '../../../widgets/dashboard/water_level_widget.dart';
import '../../../widgets/dashboard/weather_widget.dart';
import '../../../widgets/dashboard/weekly_challenge_highlight.dart';
import '../../../widgets/dashboard/weekly_digest.dart';
import '../../../widgets/dashboard/widget_grid_settings.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/post_card.dart';

class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  ConsumerState<DashboardHomeScreen> createState() =>
      _DashboardHomeScreenState();
}

class _DashboardHomeScreenState
    extends ConsumerState<DashboardHomeScreen> {
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
    // Profil zuerst — wir brauchen lat/lng + radius_km fuer den Nearby-Call.
    // Ohne Koordinaten fiel getNearby() blind auf _latestActive(limit:10)
    // zurueck — geografisches Ranking war ausgeschaltet.
    final profile = await ProfilesRepository.getMine();
    final lat = profile?.latitude ?? profile?.homeLat;
    final lng = profile?.longitude ?? profile?.homeLng;
    final radiusKm = profile?.radiusKm ?? 25;
    final results = await Future.wait<dynamic>([
      Future<Profile?>.value(profile),
      NotificationsRepository.unreadCount(),
      InteractionsRepository.activeCount(),
      PostsRepository.getNearby(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        limit: 15,
      ),
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
            // UX: bei Cold-Start (data noch null + loading) zeigen wir
            // ein Skeleton statt weisser Flaeche. Sobald data da ist,
            // rendert die echte Liste.
            if (loading && data == null) {
              return const ListSkeleton(count: 5);
            }
            final children = _buildChildren(cfg, data, loading);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            );
          },
        ),
      ),
    );
  }

  /// Iteriert die User-konfigurierte Reihenfolge und rendert nur sichtbare
  /// Widgets. V14 horizontale Sections werden ueber Helper gebuendelt.
  List<Widget> _buildChildren(
    DashboardWidgetConfig cfg,
    _DashboardData? data,
    bool loading,
  ) {
    final out = <Widget>[];
    final visible = cfg.visible;
    final order = cfg.order;
    final profile = data?.profile;
    final posts = data?.posts ?? const <Post>[];

    // Set damit wir mehrfach-gerenderte IDs uebersrpringen (V14 grouping).
    final consumed = <String>{};

    void addSpacing([double h = 16]) =>
        out.add(SizedBox(height: h));

    for (final id in order) {
      if (!visible.contains(id) || consumed.contains(id)) continue;

      switch (id) {
        case 'hero':
          out.add(DashboardHeroCard(
            profile: profile,
            memberSinceDays: profile == null
                ? 0
                : DateTime.now().difference(profile.createdAt).inDays,
          ));
          addSpacing(14);
          break;
        case 'safety':
          out.add(SafetyBanners(
            lat: profile?.latitude,
            lng: profile?.longitude,
          ));
          addSpacing(14);
          break;
        case 'onboarding':
          if (profile != null) {
            out.add(OnboardingChecklist(profile: profile, posts: posts));
            addSpacing();
          }
          break;
        case 'quick_actions':
          if (profile != null) {
            out.add(Text('home.quickActions'.tr(),
                style: AppTypography.label(size: 10)));
            out.add(const SizedBox(height: 8));
            out.add(const QuickActions());
            addSpacing();
          }
          break;
        case 'unread_messages':
          if (profile != null) {
            out.add(const UnreadMessagesWidget());
            addSpacing();
          }
          break;
        case 'stats':
          if (profile != null) {
            out.add(StatsRow(
              data: StatsRowData(
                profile: data!.profile,
                unreadCount: data.unreadCount,
                activeInteractions: data.activeInteractions,
                posts: data.posts,
              ),
              loading: loading,
            ));
            addSpacing();
          }
          break;
        case 'smart_match':
          // V14: SmartMatch + WeeklyChallenge zu Swipe-Stack zusammenlegen.
          if (profile == null) break;
          if (visible.contains('weekly_challenge')) {
            consumed.add('weekly_challenge');
            out.add(_SectionHeader(
              icon: LucideIcons.sparkles,
              label: 'home.smartMatch'.tr(),
              routeAll: '/dashboard/matching',
            ));
            out.add(const SizedBox(height: 8));
            out.add(const _SwipeStack(children: [
              SmartMatchWidget(),
              WeeklyChallengeHighlight(),
            ]));
          } else {
            out.add(const SmartMatchWidget());
          }
          addSpacing();
          break;
        case 'weekly_challenge':
          // Standalone (smart_match already not visible).
          if (profile == null) break;
          out.add(const WeeklyChallengeHighlight());
          addSpacing();
          break;
        case 'rating_prompt':
          if (profile != null) {
            out.add(RatingPromptBanner(userId: profile.id));
            addSpacing();
          }
          break;
        case 'trust_score':
          // V14: Trust + Weather + Holiday als horizontale Reihe.
          if (profile == null) break;
          final hasGeo =
              profile.latitude != null && profile.longitude != null;
          final showWeather =
              visible.contains('weather') && hasGeo;
          final showHoliday =
              visible.contains('holiday_badge') && hasGeo;
          if (showWeather || showHoliday) {
            if (visible.contains('weather')) consumed.add('weather');
            if (visible.contains('holiday_badge')) {
              consumed.add('holiday_badge');
            }
            out.add(_SectionHeader(
              icon: LucideIcons.shieldCheck,
              label: 'home.trust'.tr(),
              routeAll: '/dashboard/profile',
            ));
            out.add(const SizedBox(height: 8));
            final cards = <Widget>[
              SizedBox(
                width: 320,
                child: TrustScoreCard(profile: profile),
              ),
              if (showWeather)
                SizedBox(
                  width: 320,
                  child: WeatherWidget(
                    lat: profile.latitude!,
                    lng: profile.longitude!,
                  ),
                ),
              if (showHoliday)
                SizedBox(
                  width: 320,
                  child: HolidayBadge(
                    lat: profile.latitude!,
                    lng: profile.longitude!,
                  ),
                ),
              if (hasGeo)
                SizedBox(
                  width: 320,
                  child: WaterLevelWidget(
                    lat: profile.latitude!,
                    lng: profile.longitude!,
                  ),
                ),
            ];
            out.add(SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final c in cards) ...[
                    c,
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ));
          } else {
            out.add(TrustScoreCard(profile: profile));
          }
          addSpacing();
          break;
        case 'thanks':
          if (profile != null) {
            out.add(ThanksReceived(userId: profile.id));
            addSpacing();
          }
          break;
        case 'weather':
          if (profile == null) break;
          // Fallback wenn trust_score nicht sichtbar war.
          if (profile.latitude != null && profile.longitude != null) {
            out.add(WeatherWidget(
              lat: profile.latitude!,
              lng: profile.longitude!,
            ));
          } else {
            out.add(InkWell(
              onTap: () => context.go('/dashboard/settings'),
              borderRadius: BorderRadius.circular(14),
              child: const WeatherLocationCta(),
            ));
          }
          addSpacing();
          break;
        case 'holiday_badge':
          if (profile == null) break;
          if (profile.latitude != null && profile.longitude != null) {
            out.add(HolidayBadge(
              lat: profile.latitude!,
              lng: profile.longitude!,
            ));
            addSpacing();
          }
          break;
        case 'community_pulse':
          if (profile != null) {
            out.add(CommunityPulse(posts: posts));
            addSpacing();
          }
          break;
        case 'activity_feed':
          if (profile != null) {
            out.add(const ActivityFeedWidget());
            addSpacing();
          }
          break;
        case 'mini_map':
          if (profile != null) {
            if (posts.isNotEmpty) {
              out.add(MiniMapWidget(posts: posts.take(20).toList()));
            } else {
              out.add(_MapEmptyTile());
            }
            addSpacing();
          }
          break;
        case 'success_story':
          if (profile != null) {
            out.add(const SuccessStoryCard());
            addSpacing();
          }
          break;
        case 'bot_tip':
          if (profile != null) {
            out.add(const BotTipCard());
            addSpacing();
          }
          break;
        case 'weekly_digest':
          if (profile != null) {
            out.add(WeeklyDigest(profile: profile));
            addSpacing(24);
          }
          break;
        case 'traffic':
          out.add(const TrafficInfoWidget());
          addSpacing();
          break;
        case 'books':
          out.add(const BooksWidget());
          addSpacing();
          break;
        case 'health':
          out.add(const HealthWidget());
          addSpacing();
          break;
        case 'nasa_apod':
          out.add(const NasaApodWidget());
          addSpacing();
          break;
        case 'on_this_day':
          out.add(const OnThisDayWidget());
          addSpacing();
          break;
        case 'mood':
          out.add(const MoodChartWidget());
          addSpacing();
          break;
        case 'sun':
          out.add(const SunWidget());
          addSpacing();
          break;
        case 'quote':
          out.add(const DailyQuoteWidget());
          addSpacing();
          break;
        case 'streak':
          out.add(const StreakWidget());
          addSpacing();
          break;
        case 'gratitude':
          out.add(const GratitudeWidget());
          addSpacing();
          break;
        case 'karma':
          out.add(const KarmaWidget());
          addSpacing();
          break;
        case 'recap':
          out.add(const WeeklyRecapWidget());
          addSpacing();
          break;
        case 'nearby_posts':
          // Wird unten gerendert (immer am Ende).
          break;
      }
    }

    // Nearby-Posts immer am Ende — vertikaler Feed.
    out.add(Row(
      children: [
        Text(
          'home.nearbyTitle'.tr(),
          style: AppTypography.display(size: 20, color: AppColors.ink),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/dashboard/posts'),
          child: Text('home.viewAll'.tr()),
        ),
      ],
    ));
    out.add(const SizedBox(height: 8));
    out.add(_NearbyFeed(posts: posts, loading: loading));

    return out;
  }
}

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

/// V14 Section-Header — Icon + Label + "Alle →" Button.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.routeAll,
  });

  final IconData icon;
  final String label;
  final String routeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.bronze),
        const SizedBox(width: 6),
        Text(label,
            style: AppTypography.label(
                size: 10, color: AppColors.bronze)),
        const Spacer(),
        TextButton(
          onPressed: () => context.go(routeAll),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 28),
          ),
          child: Text(
            'home.viewAll'.tr(),
            style: AppTypography.label(size: 9, color: AppColors.bronze),
          ),
        ),
      ],
    );
  }
}

/// V14 Stacked Swipe-Cards — PageView mit Dots fuer SmartMatch+Challenge.
class _SwipeStack extends StatefulWidget {
  const _SwipeStack({required this.children});
  final List<Widget> children;

  @override
  State<_SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<_SwipeStack> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView(
            controller: _ctrl,
            onPageChanged: (p) => setState(() => _page = p),
            children: widget.children,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.children.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.bronze : AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _NearbyFeed extends StatelessWidget {
  const _NearbyFeed({required this.posts, required this.loading});
  final List<Post> posts;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          3,
          (i) => PostCardSkeleton(showImage: i.isEven),
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
                  size: 13, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  textStyle:
                      AppTypography.body(size: 14, weight: FontWeight.w700),
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

class _MapEmptyTile extends StatelessWidget {
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
          border:
              Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.map, size: 36, color: AppColors.bronze),
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
                        size: 12, color: AppColors.inkSoft, height: 1.4),
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
