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
import 'package:flutter/services.dart';
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
import '../../../services/permissions_gate.dart';
import '../../../widgets/dashboard/activity_feed_widget.dart';
import '../../../widgets/dashboard/alerts_badge_widget.dart';
import '../../../widgets/dashboard/dashboard_section.dart';
import '../../../widgets/dashboard/dashboard_dorf_header.dart';
// v2.1: Books-Widget entfernt — Import bleibt aus damit Linter mahnt
// wenn jemand das aus Versehen wieder einbaut.
// import '../../../widgets/dashboard/books_widget.dart';
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
import '../../../widgets/dashboard/activity_heatmap_widget.dart';
import '../../../widgets/dashboard/affirmation_widget.dart';
import '../../../widgets/dashboard/help_streak_widget.dart';
import '../../../widgets/dashboard/moon_widget.dart';
import '../../../widgets/dashboard/personal_best_widget.dart';
import '../../../widgets/dashboard/progress_trio_widget.dart';
import '../../../widgets/dashboard/quick_note_widget.dart';
import '../../../widgets/dashboard/sky_widget.dart';
import '../../../widgets/dashboard/weekly_recap_widget.dart';
import '../../../widgets/dashboard/sun_widget.dart';
import '../../../widgets/dashboard/become_mentor_cta.dart';
import '../../../widgets/dashboard/daily_challenges_widget.dart';
import '../../../widgets/dashboard/nearby_neighbors_widget.dart';
import '../../../widgets/dashboard/profile_completion_card.dart';
import '../../../widgets/dashboard/recent_routes_widget.dart';
import '../../../widgets/dashboard/today_events_widget.dart';
import '../../../widgets/dashboard/traffic_info_widget.dart';
import '../../../widgets/dashboard/dashboard_hero_card.dart';
import '../../../widgets/stories/stories_ring.dart';
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
import '../../../widgets/dashboard/weekly_summary_widget.dart';
import '../../../widgets/dashboard/dashboard_edit_banner.dart';
import '../../../widgets/dashboard/dashboard_onboarding_tooltip.dart';
import '../../../widgets/dashboard/dashboard_widget_wrapper.dart';
import '../../../widgets/dashboard/disabled_widgets_bar.dart';
import '../../../widgets/dashboard/widget_grid_settings.dart';
import '../../../widgets/effects/animated_entrance.dart';
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
    extends ConsumerState<DashboardHomeScreen>
    with SingleTickerProviderStateMixin {
  Future<_DashboardData>? _data;
  bool _locationCheckDone = false;
  // L16: Doppel-Back-Tap-to-Exit-Schutz auf Dashboard-Home.
  DateTime? _lastBackPress;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.035),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _data = _loadAll();
    _fadeCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFirstRunFlow());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Erststart-Reihenfolge OHNE Stapeln (Release-UX 2026-06).
  /// Früher feuerten Permissions-Gate, Onboarding-Tour und Standort-Sheet
  /// unabhängig voneinander → bis zu drei Overlays gleichzeitig. Jetzt
  /// strikt sequenziell: 1. Berechtigungs-Gate abwarten, 2. eine Tour,
  /// 3. danach erst die Standort-Abfrage.
  Future<void> _runFirstRunFlow() async {
    // Schritt 1: Warten, bis der Permissions-Gate nicht mehr nötig ist. Er wird
    //    von PermissionsGateGuard als eigener /gate-Screen oben gepusht; solange
    //    halten wir Tour + Standort zurück. Bounded auf ~20s als Sicherheitsnetz.
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      bool gatePending;
      try {
        gatePending = await PermissionsGate.shouldShowGate();
      } catch (_) {
        gatePending = false;
      }
      if (!mounted) return;
      final onGateRoute = GoRouterState.of(context).uri.path == '/gate';
      if (!gatePending && !onGateRoute) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    // Schritt 2: Eine Tour — kehrt sofort zurück, falls bereits gesehen.
    await OnboardingTour.maybeShow(context);
    if (!mounted) return;
    // Schritt 3: Erst JETZT die Standort-Abfrage, nie gleichzeitig zur Tour.
    final d = await _data;
    if (!mounted || d == null) return;
    await _maybeShowLocationOnboarding(d.profile);
  }

  Future<void> _maybeShowLocationOnboarding(Profile? p) async {
    if (_locationCheckDone || p == null) return;
    if (p.latitude != null && p.longitude != null) {
      _locationCheckDone = true;
      return;
    }
    _locationCheckDone = true;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          duration: const Duration(milliseconds: 1800),
          content: Text(
            'home.tapAgainToExit'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink),
          ),
        ));
      },
      child: DashboardScaffold(
        title: 'home.dashboardTitle'.tr(),
        currentRoute: '/dashboard',
      fab: FloatingActionButton.small(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.bronze,
        onPressed: () => WidgetSettingsSheet.show(context),
        tooltip: 'home.configureWidgets'.tr(),
        child: const Icon(LucideIcons.settings, size: 16),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: RefreshIndicator(
        color: AppColors.amber,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardData>(
          future: _data,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final data = snap.data;
            if (loading && data == null) {
              return const ListSkeleton(count: 5);
            }
            final isEditMode = ref.watch(isDashboardEditModeProvider);
            return PopScope(
              canPop: !isEditMode,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && isEditMode) {
                  ref.read(isDashboardEditModeProvider.notifier).state = false;
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: isEditMode
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        ref
                            .read(isDashboardEditModeProvider.notifier)
                            .state = true;
                      },
                child: _DashboardScrollBody(
                  cfg: cfg,
                  data: data,
                  loading: loading,
                  isEditMode: isEditMode,
                  buildWidgetById: _buildWidgetById,
                  buildChildren: _buildChildren,
                ),
              ),
            );
          },
        ),
          ),
        ),
      ),
      ),
    );
  }

  /// Rendert ein EINZELNES Widget per ID (für ReorderableListView im
  /// Edit-Mode). Die volle _buildChildren-Logik mit V14-Grouping wird im
  /// Normal-Modus genutzt; im Edit-Mode rendern wir flat 1-Widget-pro-ID.
  Widget _buildWidgetById(
    String id,
    DashboardWidgetConfig cfg,
    _DashboardData? data,
    bool loading,
  ) {
    // _buildChildren ist gross + V14-grouped — wir geben einen
    // Single-Item-Config und filtern dessen Output.
    final singleCfg = DashboardWidgetConfig(
      order: [id],
      visible: {id},
      version: cfg.version,
    );
    final widgets = _buildChildren(singleCfg, data, loading);
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
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

    // Ruhigeres Layout: etwas mehr Weißraum zwischen den Widgets (16 → 18).
    void addSpacing([double h = 18]) =>
        out.add(SizedBox(height: h));

    // Phase 10 A/B/C: Sektion-Banner zwischen Widget-Gruppen.
    // Tageszeit-Sortierung beeinflusst hier die Reihenfolge der Sektionen.
    DashboardSectionId? currentSection;
    final sectionPriority = {
      for (var i = 0;
          i < orderedSections(DateTime.now()).length;
          i++)
        orderedSections(DateTime.now())[i].id: i,
    };

    // PINNED HEADERS: hero + onboarding + safety + stats müssen IMMER
    // ganz oben bleiben, unabhängig von Tageszeit/Sektion und niemals
    // collapse-bar. User-Wunsch (2026-05): die Hero-Begrüßungs-Karte
    // (Guten Tag / Avatar / Bearbeiten / Vollprofil) MUSS fest ganz oben
    // sein — kein User-Reorder kann sie verschieben.
    // quick_actions gehört zum Dashboard-Kopf (Schnellaktionen + Recent-
    // Routes) — ohne Sektion sortierte es vorher ans ENDE (Priorität 999).
    // Pinnen hält die Kern-Navigation oben (Struktur-Fix „schief angeordnet").
    const pinnedTop = {'hero', 'onboarding', 'safety', 'stats', 'quick_actions'};
    // Feste Reihenfolge der Pinned. Hero IMMER #0.
    const pinnedFixedOrder = [
      'hero',
      'onboarding',
      'safety',
      'stats',
      'quick_actions',
    ];
    int pinnedRank(String id) {
      final idx = pinnedFixedOrder.indexOf(id);
      return idx < 0 ? 999 : idx;
    }
    // Dedupe: eine korrupt gespeicherte/gesyncte Config (alter Bug) konnte
    // IDs doppelt enthalten → Widget rendert doppelt. toSet() hält die
    // Einfüge-Reihenfolge (LinkedHashSet) und entfernt Duplikate.
    final sortedOrder = order.toSet().toList();
    sortedOrder.sort((a, b) {
      final pinnedA = pinnedTop.contains(a);
      final pinnedB = pinnedTop.contains(b);
      if (pinnedA && !pinnedB) return -1;
      if (!pinnedA && pinnedB) return 1;
      if (pinnedA && pinnedB) {
        // Pinned-vs-Pinned: feste Reihenfolge, NICHT user-order-abhängig.
        return pinnedRank(a).compareTo(pinnedRank(b));
      }
      final sa = sectionForWidget(a);
      final sb = sectionForWidget(b);
      final pa = sa == null ? 999 : (sectionPriority[sa.id] ?? 999);
      final pb = sb == null ? 999 : (sectionPriority[sb.id] ?? 999);
      if (pa != pb) return pa.compareTo(pb);
      return order.indexOf(a).compareTo(order.indexOf(b));
    });

    // Defensive: stelle sicher dass 'hero' in sortedOrder existiert und
    // ganz vorne steht — selbst wenn der User irgendwie das order-Array
    // korrumpiert hat. Hero darf NIE verloren gehen.
    if (!sortedOrder.contains('hero')) {
      sortedOrder.insert(0, 'hero');
    }

    // Vorab-Konsum (reihenfolge-UNABHÄNGIG): Gruppen-Widgets fassen mehrere
    // Einzel-Widgets zusammen und „konsumieren" sie. Vorher geschah das erst
    // im jeweiligen case — stand ein Mitglied VOR seiner Gruppe in der
    // (user-sortierbaren) order, rendete es doppelt (z. B. streak + erneut
    // in progress_trio). Jetzt werden die Mitglieder schon vor dem Loop
    // markiert, sobald ihre Gruppe aktiv ist (mit identischen Bedingungen
    // wie im case), egal wie die Reihenfolge ist.
    bool groupActive(String id) => id == 'hero' || visible.contains(id);
    if (groupActive('progress_trio')) {
      consumed.addAll(const ['karma', 'streak', 'helpStreak']);
    }
    if (groupActive('sky') &&
        profile?.latitude != null &&
        profile?.longitude != null) {
      consumed.addAll(const ['weather', 'sun', 'moon']);
    }
    if (groupActive('weekly_summary') && profile != null) {
      consumed.addAll(const ['recap', 'digest']);
    }
    if (groupActive('alerts_badge')) {
      consumed.addAll(const ['safety', 'traffic', 'water_level']);
    }

    for (final id in sortedOrder) {
      // Hero ist nicht-verbergbar (User-Wunsch). Auch wenn visible-Set
      // hero nicht enthält, rendern wir es trotzdem.
      if (id != 'hero' &&
          (!visible.contains(id) || consumed.contains(id))) {
        continue;
      }
      if (consumed.contains(id)) continue;
      final isPinned = pinnedTop.contains(id);
      // Pinned-Widgets: KEIN Sektion-Banner.
      if (isPinned) {
        // Fall-through zur Case-Switch.
      } else {
        // User-Wunsch (2026-05): Sektionen bleiben als optische Trenner,
        // sind aber IMMER offen — kein Collapse-Toggle, kein Skip-Effekt.
        // Sektion-Banner einfügen wenn sich die Sektion ändert.
        final widgetSection = sectionForWidget(id);
        if (widgetSection != null && widgetSection.id != currentSection) {
          currentSection = widgetSection.id;
          out.add(_SectionBanner(section: widgetSection));
        }
      }

      switch (id) {
        case 'hero':
          // B2 Mikro-Physik: der EINE Hero-Moment des Dashboards bekommt
          // den Spring-Entrance (Overshoot) — Listen bleiben easeOut.
          out.add(AnimatedEntrance(
            spring: true,
            child: DashboardHeroCard(
              profile: profile,
              memberSinceDays: profile == null
                  ? 0
                  : DateTime.now().difference(profile.createdAt).inDays,
            ),
          ));
          // F59 Stories-Ring direkt unter dem Hero.
          out.add(const StoriesRing());
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
            // N3: Recent-Routes-Chips zuerst (zuletzt besucht)
            out.add(const RecentRoutesWidget());
            out.add(const SizedBox(height: 8));
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
          // v2.1: Books-Widget entfernt (User-Wunsch).
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
        // Phase 10 E4: ProgressTrio = Karma + Streak + HelpStreak in Row.
        case 'progress_trio':
          out.add(const ProgressTrioWidget());
          consumed.addAll(const ['karma', 'streak', 'helpStreak']);
          addSpacing();
          break;
        // Phase 10 E3: SkyWidget = Weather + Sun + Moon im PageView.
        case 'sky':
          if (profile?.latitude != null && profile?.longitude != null) {
            out.add(SkyWidget(
              lat: profile!.latitude!,
              lng: profile.longitude!,
            ));
            consumed.addAll(const ['weather', 'sun', 'moon']);
            addSpacing();
          }
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
        // Phase 10 E6: WeeklySummary = Recap + Digest in einem TabBar.
        case 'weekly_summary':
          if (profile != null) {
            out.add(WeeklySummaryWidget(profile: profile));
            consumed.addAll(const ['recap', 'digest']);
            addSpacing();
          }
          break;
        // Phase 10 E9: AlertsBadge = idle 'Alles sicher' / aktiv SafetyBanners.
        case 'alerts_badge':
          out.add(AlertsBadgeWidget(
            lat: profile?.latitude,
            lng: profile?.longitude,
          ));
          consumed.addAll(const ['safety', 'traffic', 'water_level']);
          addSpacing();
          break;
        case 'heatmap':
          out.add(const ActivityHeatmapWidget());
          addSpacing();
          break;
        case 'quickNote':
          out.add(const QuickNoteWidget());
          addSpacing();
          break;
        case 'helpStreak':
          out.add(const HelpStreakWidget());
          addSpacing();
          break;
        case 'moon':
          out.add(const MoonWidget());
          addSpacing();
          break;
        case 'personalBest':
          out.add(const PersonalBestWidget());
          addSpacing();
          break;
        case 'affirmation':
          out.add(const AffirmationWidget());
          addSpacing();
          break;
        case 'todayEvents':
          out.add(const TodayEventsWidget());
          addSpacing();
          break;
        case 'dailyChallenges':
          out.add(const DailyChallengesWidget());
          addSpacing();
          out.add(const BecomeMentorCta());
          addSpacing();
          // D1: Neu in deiner Nachbarschaft — Avatar-Reihe der letzten
          // 5-10 Neu-Anmeldungen im 50km-Umkreis (letzte 14 Tage).
          out.add(const NearbyNeighborsWidget());
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
                onPressed: () => context.go('/dashboard/modules'),
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
                    'home.mapEmptyBody'.tr(),
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


// ═══════════════════════════════════════════════════════════════════
// Edit-Mode Scroll-Body: ReorderableListView wenn editMode, sonst
// normale Column für volle V14-Grouping-Performance.
// ═══════════════════════════════════════════════════════════════════
class _DashboardScrollBody extends ConsumerWidget {
  const _DashboardScrollBody({
    required this.cfg,
    required this.data,
    required this.loading,
    required this.isEditMode,
    required this.buildWidgetById,
    required this.buildChildren,
  });

  final DashboardWidgetConfig cfg;
  final _DashboardData? data;
  final bool loading;
  final bool isEditMode;
  final Widget Function(String, DashboardWidgetConfig, _DashboardData?, bool)
      buildWidgetById;
  final List<Widget> Function(DashboardWidgetConfig, _DashboardData?, bool)
      buildChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEditMode) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const DashboardDorfHeader(),
          const ProfileCompletionCard(),
          const DashboardOnboardingTooltip(),
          ...buildChildren(cfg, data, loading),
        ],
      );
    }
    final ids = cfg.activeWidgetIds;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: DashboardEditBanner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          sliver: SliverReorderableList(
            itemCount: ids.length,
            proxyDecorator: (child, index, animation) => Material(
              elevation: 8,
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.05,
                child: Opacity(opacity: 0.92, child: child),
              ),
            ),
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(dashboardWidgetConfigProvider.notifier)
                  .reorder(oldIndex, newIndex);
              HapticFeedback.selectionClick();
            },
            itemBuilder: (_, i) {
              final id = ids[i];
              return Padding(
                key: ValueKey('edit-$id'),
                padding: const EdgeInsets.only(bottom: 14, top: 6),
                child: DashboardWidgetWrapper(
                  widgetId: id,
                  isEditMode: true,
                  dragIndex: i,
                  child: buildWidgetById(id, cfg, data, loading),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: DisabledWidgetsBar()),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}


/// Phase 10 D1/D2: kompakter Sektion-Banner zwischen Widget-Gruppen.
/// Glassmorphism + Sektions-Farbe als Linker-Rand. User-Wunsch (2026-05):
/// reiner optischer Trenner — KEIN Toggle, KEIN Collapse. Sektionen sind
/// immer offen.
class _SectionBanner extends StatelessWidget {
  const _SectionBanner({required this.section});
  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    // Editorial-Header statt buntem Banner: Akzent-Punkt + Icon +
    // Versal-Label + Haarlinie, die über die Restbreite ausläuft. Ruhiger,
    // hochwertiger, konsistent mit den Modul-Screens (§-Editorial-Stil).
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: section.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: section.color.withValues(alpha: 0.5),
                    blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(section.icon, size: 13, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(
            section.titleKey.tr().toUpperCase(),
            style: AppTypography.label(
              size: 10,
              color: AppColors.inkSoft,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.bronze.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
