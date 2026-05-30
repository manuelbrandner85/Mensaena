import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/role_provider.dart';
import '../../screens/dashboard/board/board_create_screen.dart';
import '../../screens/dashboard/board/board_detail_screen.dart';
import '../../screens/dashboard/board/board_screen.dart';
import '../../screens/dashboard/admin/admin_bot_feedback_screen.dart';
import '../../screens/dashboard/admin/admin_challenges_screen.dart';
import '../../screens/dashboard/admin/admin_chat_moderation_screen.dart';
import '../../screens/dashboard/admin/admin_contact_screen.dart';
import '../../screens/dashboard/admin/admin_dashboard_screen.dart';
import '../../screens/dashboard/admin/admin_groups_screen.dart';
import '../../screens/dashboard/admin/admin_system_screen.dart';
import '../../screens/dashboard/admin/admin_table_screen.dart';
import '../../screens/dashboard/admin/admin_users_screen.dart';
import '../../screens/dashboard/admin/admin_zeitbank_screen.dart';
import '../../screens/dashboard/badges/badges_screen.dart';
import '../../screens/dashboard/call/call_history_screen.dart';
import '../../screens/dashboard/call/call_screen.dart';
import '../../screens/dashboard/live/live_room_screen.dart';
import '../../screens/dashboard/followed_tags_screen.dart';
import '../../screens/dashboard/friends_screen.dart';
import '../../screens/dashboard/global_search_screen.dart';
import '../../screens/dashboard/modules_hub_screen.dart';
import '../../screens/dashboard/profile_edit_screen.dart';
import '../../screens/dashboard/profile_saved_screen.dart';
import '../../screens/dashboard/calendar_screen.dart';
import '../../screens/dashboard/challenges/challenge_create_screen.dart';
import '../../screens/dashboard/challenges/challenges_screen.dart';
import '../../screens/dashboard/create/module_create_config.dart';
import '../../screens/dashboard/create/module_create_post_screen.dart';
import '../../screens/dashboard/groups/group_create_screen.dart';
import '../../screens/dashboard/groups/group_detail_screen.dart';
import '../../screens/dashboard/groups/groups_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_create_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_detail_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_screen.dart';
import '../../screens/dashboard/matching/matching_screen.dart';
import '../../screens/dashboard/organizations/organization_detail_screen.dart';
import '../../screens/dashboard/organizations/organization_suggest_screen.dart';
import '../../screens/dashboard/organizations/organizations_screen.dart';
import '../../screens/dashboard/supply/farm_create_screen.dart';
import '../../screens/dashboard/supply/farm_detail_screen.dart';
import '../../screens/dashboard/supply/foodbanks_screen.dart';
import '../../screens/dashboard/supply/supply_screen.dart';
import '../../screens/dashboard/chat/chat_screen.dart';
import '../../screens/dashboard/community_polls_screen.dart';
import '../../screens/dashboard/contact_requests_screen.dart';
import '../../screens/dashboard/account_screen.dart';
import '../../screens/dashboard/drafts_screen.dart';
import '../../screens/dashboard/karma_history_screen.dart';
import '../../screens/dashboard/admin/admin_crash_logs_screen.dart';
import '../../screens/dashboard/call/scheduled_calls_screen.dart';
import '../../screens/dashboard/call/voicemail_screen.dart';
import '../../screens/dashboard/mentorship_match_screen.dart';
import '../../screens/dashboard/live/scheduled_streams_screen.dart';
import '../../screens/dashboard/mentorship_screen.dart';
import '../../screens/dashboard/leaderboard_screen.dart';
// import '../../screens/dashboard/create_post_screen.dart'; // S8: entfernt — Modul-spezifische Creates
import '../../screens/dashboard/crisis/crisis_create_screen.dart';
import '../../screens/dashboard/crisis/crisis_dashboard_screen.dart';
import '../../screens/dashboard/crisis/crisis_detail_screen.dart';
import '../../screens/dashboard/crisis/crisis_resources_screen.dart';
import '../../screens/dashboard/home/dashboard_home_screen.dart';
import '../../screens/dashboard/knowledge/knowledge_create_screen.dart';
import '../../screens/dashboard/knowledge/knowledge_screen.dart';
import '../../screens/dashboard/module/module_posts_screen.dart';
import '../../screens/dashboard/skills/skills_screen.dart';
import '../../screens/dashboard/teilen/teilen_hub_screen.dart';
import '../../screens/dashboard/wissen/wissen_hub_screen.dart';
import '../../screens/dashboard/events/event_create_screen.dart';
import '../../screens/dashboard/events/event_detail_screen.dart';
import '../../screens/dashboard/events/events_screen.dart';
import '../../screens/dashboard/interactions_screen.dart';
import '../../screens/dashboard/invite/invite_screen.dart';
import '../../screens/dashboard/mental_support/mental_support_screen.dart';
import '../../screens/dashboard/map_screen.dart';
import '../../screens/dashboard/messages_screen.dart';
import '../../screens/dashboard/notifications_screen.dart';
import '../../screens/dashboard/post_detail_screen.dart';
import '../../screens/dashboard/posts_list_screen.dart';
import '../../screens/dashboard/profile_screen.dart';
import '../../screens/dashboard/ratings_hub_screen.dart';
import '../../screens/dashboard/settings_screen.dart';
import '../../screens/legal/legal_page_screen.dart';
import '../../screens/legal/unsubscribe_screen.dart';
import '../../screens/dashboard/timebank_screen.dart';
import '../../screens/dashboard/harvest/wild_picks_screen.dart';
import '../../screens/dashboard/jobs/job_portals_screen.dart';
import '../../screens/dashboard/jobs/live_jobs_screen.dart';
import '../../screens/dashboard/mobility/charge_stations_screen.dart';
import '../../screens/dashboard/mobility/gas_prices_screen.dart';
import '../../screens/dashboard/species/identify_species_screen.dart';
import '../../screens/dashboard/warnungen/air_quality_screen.dart';
import '../../screens/dashboard/warnungen/civil_protection_screen.dart';
import '../../screens/dashboard/warnungen/food_warnings_screen.dart';
import '../../screens/dashboard/warnungen/meteoalarm_screen.dart';
import '../../screens/dashboard/warnungen/warnungen_screen.dart';
import '../../screens/misc/placeholder_screen.dart';
import '../../screens/public/auth_screen.dart';
import '../../screens/public/landing_screen.dart';
import '../../screens/public/onboarding_tour_screen.dart';
import '../../screens/public/splash_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/shared/filter_chip_bar.dart';
import 'page_transitions.dart';

/// SKILL: flutter-setup-declarative-routing
/// Globaler RootNavigator-Key — von CallkitService/IncomingCallListener
/// genutzt um aus jedem Kontext (auch wenn das BuildContext nicht im Tree
/// ist) auf den Call-Screen zu navigieren, insbesondere im Cold-Start-Fall.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Alle Routen der App. Public-Routen sind ohne Login zugaenglich,
/// alle anderen werden bei nicht-Login zu /auth umgeleitet.
/// initialLocation = /splash: Splash-Screen ist der erste Screen.
/// Splash navigiert nach ~1.6s zum Dashboard (wenn eingeloggt) oder /auth.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final loggedIn = SupabaseService.isLoggedIn;
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuthRoute =
          loc == '/auth' || loc == '/login' || loc == '/register';
      final isPublicInfo = _publicRoutes.any(
        (p) => p != '/' && (loc == p || loc.startsWith('$p/')),
      );

      // Splash darf von jedem Status angezeigt werden (selbst-navigierend)
      if (isSplash) return null;

      if (!loggedIn) {
        if (isAuthRoute) return null;
        if (isPublicInfo) return null;
        return '/auth?mode=login';
      }
      if (loggedIn && (isAuthRoute || loc == '/')) {
        return '/dashboard';
      }
      // Admin-Route-Guard: nur fuer admin/moderator. Defense-in-depth
      // gegen RLS-Luecken. UserRoleCache wird beim Login geladen.
      if (loc.startsWith('/dashboard/admin')) {
        if (!UserRoleCache.isModerator) {
          return '/dashboard';
        }
      }
      return null;
    },
    routes: <RouteBase>[
      // ── Splash ─────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const OnboardingTourScreen(),
        ),
      ),
      // ── Public ─────────────────────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LandingScreen(),
        ),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: AuthScreen(
          mode: s.uri.queryParameters['mode'] ?? 'login',
        ),
        ),
      ),
      GoRoute(path: '/login', redirect: (_, __) => '/auth?mode=login'),
      GoRoute(path: '/register', redirect: (_, __) => '/auth?mode=register'),
      GoRoute(
        path: '/about',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'about'),
        ),
      ),
      GoRoute(
        path: '/spenden',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const SpendenScreen(),
        ),
      ),
      GoRoute(
        path: '/kontakt',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'kontakt'),
        ),
      ),
      GoRoute(
        path: '/impressum',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'impressum'),
        ),
      ),
      GoRoute(
        path: '/datenschutz',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'datenschutz'),
        ),
      ),
      GoRoute(
        path: '/agb',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'agb'),
        ),
      ),
      GoRoute(
        path: '/haftungsausschluss',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'haftungsausschluss'),
        ),
      ),
      GoRoute(
        path: '/nutzungsbedingungen',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'nutzungsbedingungen'),
        ),
      ),
      GoRoute(
        path: '/community-guidelines',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LegalPageScreen(contentKey: 'community-guidelines'),
        ),
      ),
      _placeholder('/download', 'Download'),
      GoRoute(
        path: '/search',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: GlobalSearchScreen(
          initialQuery: s.uri.queryParameters['q'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/search',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: GlobalSearchScreen(
          initialQuery: s.uri.queryParameters['q'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/followed-tags',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: const FollowedTagsScreen(),
        ),
      ),
      // ZUSATZ-4F: Freundesliste mit Tabs Alle / Online / Anfragen.
      GoRoute(
        path: '/dashboard/friends',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: const FriendsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/modules',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: const ModulesHubScreen(),
        ),
      ),
      GoRoute(
        path: '/unsubscribe',
        pageBuilder: (_, s) => mensaenaTransition<void>(
          key: s.pageKey,
          child: UnsubscribeScreen(token: s.uri.queryParameters['token']),
        ),
      ),
      _placeholder('/live-ended', 'Session beendet'),
      GoRoute(
        path: '/ratings',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const RatingsHubScreen(),
        ),
      ),

      // ── Dashboard ──────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const DashboardHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/map',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const MapScreen(),
        ),
      ),
      // S8 + v2.1: zentralen Create-Post-Screen entfernt. Jedes Modul hat
      // einen eigenen Create-Flow (FAB im Module-Posts-Screen). Alte
      // /dashboard/create-Links redirecten zum Modules-Hub damit der User
      // zuerst ein Modul auswählt.
      GoRoute(
        path: '/dashboard/create',
        redirect: (_, s) => '/dashboard/modules',
      ),
      GoRoute(
        path: '/dashboard/chat',
        pageBuilder: (_, s) {
          final conv = s.uri.queryParameters['conv'];
          final Widget child = conv != null
              ? ChatScreen(conversationId: conv)
              : const MessagesScreen(initialTab: 0);
          return mensaenaTransition<void>(key: s.pageKey, child: child);
        },
      ),
      GoRoute(
        path: '/dashboard/messages',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const MessagesScreen(initialTab: 1),
        ),
        routes: [
          GoRoute(
            path: ':conversationId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: ChatScreen(
                conversationId: s.pathParameters['conversationId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/posts',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const PostsListScreen(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: PostDetailScreen(postId: s.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/profile',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
        routes: [
          // WICHTIG: literale Subroutes (edit/saved) MUESSEN vor der
          // :userId-Wildcard stehen. Sonst matched GoRouter
          // "/dashboard/profile/edit" als ProfileScreen(userId:"edit").
          // Resultat war ein Fremd-Profil mit "Nachbar:in" + Melden/Blockieren.
          GoRoute(
            path: 'edit',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: const ProfileEditScreen(),
            ),
          ),
          GoRoute(
            path: 'saved',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: const ProfileSavedScreen(),
            ),
          ),
          GoRoute(
            path: ':userId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: ProfileScreen(userId: s.pathParameters['userId']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/settings',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/notifications',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      // ── Module-spezifische Create-Pages (1:1 zu Web
      //    /dashboard/<module>/create) ───────────────────────
      GoRoute(
        path: '/dashboard/animals/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.animals),
        ),
      ),
      GoRoute(
        path: '/dashboard/housing/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.housing),
        ),
      ),
      GoRoute(
        path: '/dashboard/mobility/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.mobility),
        ),
      ),
      GoRoute(
        path: '/dashboard/sharing/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.sharing),
        ),
      ),
      GoRoute(
        path: '/dashboard/harvest/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.harvest),
        ),
      ),
      GoRoute(
        path: '/dashboard/community/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.community),
        ),
      ),
      // Wissen/Wiki nutzt eigenes Schema `knowledge_articles`
      // (kein posts-Entry) — daher dedicated Create-Screen.
      GoRoute(
        path: '/dashboard/knowledge/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const KnowledgeCreateScreen(
            routePath: '/dashboard/knowledge'),
        ),
      ),
      GoRoute(
        path: '/dashboard/wiki/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const KnowledgeCreateScreen(
            routePath: '/dashboard/wiki'),
        ),
      ),
      GoRoute(
        path: '/dashboard/skills/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.skills),
        ),
      ),
      GoRoute(
        path: '/dashboard/jobs/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.jobs),
        ),
      ),
      GoRoute(
        path: '/dashboard/rescuer/create',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.rescuer),
        ),
      ),
      GoRoute(
        path: '/dashboard/animals',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'nav.animals'.tr(),
          emoji: '🐾',
          postType: 'animal',
          route: '/dashboard/animals',
          subtitle: 'modules.animals.subtitle'.tr(),
          quickActions: const [
            ModuleQuickAction(
              icon: LucideIcons.camera,
              label: 'identify.title',
              route: '/dashboard/identify',
              color: Color(0xFF7BD389),
            ),
          ],
          subFilters: const [
            FilterOption(value: 'lost', label: '😢 Vermisst'),
            FilterOption(value: 'found', label: '🔍 Gefunden'),
            FilterOption(value: 'care', label: '🏠 Pflege'),
            FilterOption(value: 'adoption', label: '❤️ Adoption'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/housing',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'nav.housing'.tr(),
          emoji: '🏡',
          postType: 'housing',
          route: '/dashboard/housing',
          subtitle: 'modules.housing.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'seeking', label: '🔍 Suche'),
            FilterOption(value: 'offering', label: '🎁 Biete'),
            FilterOption(value: 'wg', label: '🏠 WG'),
            FilterOption(value: 'emergency', label: '🚨 Notunterkunft'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/mobility',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'nav.mobility'.tr(),
          emoji: '🚗',
          postType: 'mobility',
          route: '/dashboard/mobility',
          subtitle: 'modules.mobility.subtitle'.tr(),
          quickActions: const [
            ModuleQuickAction(
              icon: LucideIcons.zap,
              label: 'charge.title',
              route: '/dashboard/charge-stations',
              color: Color(0xFF66C7C8),
            ),
            ModuleQuickAction(
              icon: LucideIcons.fuel,
              label: 'gas.title',
              route: '/dashboard/mobility/gas',
              color: Color(0xFFE8A24A),
            ),
          ],
          subFilters: const [
            FilterOption(value: 'rideshare', label: '🚗 Mitfahrt'),
            FilterOption(value: 'carpool', label: '👥 Fahrgemeinschaft'),
            FilterOption(value: 'transport', label: '📦 Transport'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/harvest',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'nav.harvest'.tr(),
          emoji: '🌾',
          postType: 'supply',
          moduleKey: 'harvest',
          route: '/dashboard/harvest',
          quickActions: const [
            ModuleQuickAction(
              icon: LucideIcons.apple,
              label: 'wildPicks.title',
              route: '/dashboard/harvest-wild',
              color: Color(0xFF7BD389),
            ),
          ],
          subtitle: 'modules.harvest.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'fruit', label: '🍎 Obst'),
            FilterOption(value: 'vegetable', label: '🥕 Gemüse'),
            FilterOption(value: 'herbs', label: '🌿 Kräuter'),
            FilterOption(value: 'eggs', label: '🥚 Eier/Milch'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/community',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'navGroups.community'.tr(),
          emoji: '🗳️',
          postType: 'community',
          route: '/dashboard/community',
          subtitle: 'modules.community.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'discussion', label: '💬 Diskussion'),
            FilterOption(value: 'meeting', label: '👥 Treffen'),
            FilterOption(value: 'announcement', label: '📣 Ankündigung'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/wiki',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: KnowledgeScreen(
          title: 'modules.wiki'.tr(),
          routePath: '/dashboard/wiki',
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/knowledge',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: KnowledgeScreen(
          title: 'nav.knowledge'.tr(),
          routePath: '/dashboard/knowledge',
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/groups',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const GroupsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const GroupCreateScreen(),
            ),
          ),
          GoRoute(
            path: ':groupId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: GroupDetailScreen(
                groupId: s.pathParameters['groupId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/marketplace',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const MarketplaceScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const MarketplaceCreateScreen(),
            ),
          ),
          GoRoute(
            path: ':listingId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: MarketplaceDetailScreen(
                listingId: s.pathParameters['listingId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/events',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const EventsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const EventCreateScreen(),
            ),
          ),
          GoRoute(
            path: ':eventId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: EventDetailScreen(
                eventId: s.pathParameters['eventId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/calendar',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const CalendarScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/challenges',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ChallengesScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const ChallengeCreateScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/badges',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const BadgesScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/timebank',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const TimebankScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/skills',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const SkillsScreen(),
        ),
      ),
      // Modul-Audit Sprint 2 — Hub-Routes konsolidieren 3+3 Drawer-Items.
      GoRoute(
        path: '/dashboard/wissen',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const WissenHubScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/teilen',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const TeilenHubScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/organizations',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const OrganizationsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'suggest',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const OrganizationSuggestScreen(),
            ),
          ),
          GoRoute(
            path: ':orgId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: OrganizationDetailScreen(
              orgId: s.pathParameters['orgId']!,
            ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/supply',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const SupplyScreen(),
        ),
        routes: [
          GoRoute(
            path: 'farm/add',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const FarmCreateScreen(),
            ),
          ),
          GoRoute(
            path: 'foodbanks',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const FoodbanksScreen(),
            ),
          ),
          GoRoute(
            path: ':slug',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: FarmDetailScreen(
                slug: s.pathParameters['slug']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/crisis',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const CrisisDashboardScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const CrisisCreateScreen(),
            ),
          ),
          GoRoute(
            path: 'resources',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const CrisisResourcesScreen(),
            ),
          ),
          GoRoute(
            path: ':crisisId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: CrisisDetailScreen(
                crisisId: s.pathParameters['crisisId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/warnungen',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const WarnungenScreen(),
        ),
        routes: [
          GoRoute(
            path: 'food',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const FoodWarningsScreen(),
            ),
          ),
          GoRoute(
            path: 'air',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const AirQualityScreen(),
            ),
          ),
          GoRoute(
            path: 'meteo',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const MeteoAlarmScreen(),
            ),
          ),
          GoRoute(
            path: 'civil',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const CivilProtectionScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/board',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const BoardScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (_, state) => mensaenaTransition<void>(
              key: state.pageKey,
              child: const BoardCreateScreen(),
            ),
          ),
          GoRoute(
            path: ':boardPostId',
            pageBuilder: (_, s) => mensaenaTransition<void>(
              key: s.pageKey,
              child: BoardDetailScreen(
              boardPostId: s.pathParameters['boardPostId']!,
            ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/mental-support',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const MentalSupportScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/matching',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const MatchingScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/rescuer',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'modules.rescue'.tr(),
          emoji: '🛟',
          postType: 'rescue',
          route: '/dashboard/rescuer',
          subtitle: 'modules.rescuer.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'food', label: '🍎 Lebensmittel'),
            FilterOption(value: 'everyday', label: '👕 Kleidung'),
            FilterOption(value: 'sharing', label: '📦 Gegenstände'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/sharing',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'modules.sharingTitle'.tr(),
          emoji: '🔄',
          postType: 'sharing',
          route: '/dashboard/sharing',
          subtitle: 'modules.sharing.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'tools', label: '🔧 Werkzeug'),
            FilterOption(value: 'books', label: '📚 Bücher'),
            FilterOption(value: 'devices', label: '📱 Geräte'),
            FilterOption(value: 'kitchen', label: '🍴 Küche'),
            FilterOption(value: 'sports', label: '⚽ Sport'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/jobs-portals',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const JobPortalsScreen(),
        ),
      ),
      // Live-Jobsuche via Bundesagentur (nur DE, brauchbar mit PLZ).
      GoRoute(
        path: '/dashboard/jobs-search',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const LiveJobsScreen(),
        ),
      ),
      // Foto-Bestimmung via iNaturalist (Animals + Wissen)
      GoRoute(
        path: '/dashboard/identify',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const IdentifySpeciesScreen(),
        ),
      ),
      // Wildfruchte + Verschenk-Schraenke (OSM-Overpass)
      GoRoute(
        path: '/dashboard/harvest-wild',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const WildPicksScreen(),
        ),
      ),
      // E-Auto-Ladestationen (OSM-Overpass) — bleibt für Nostalgie, aber
      // User-Wunsch: durch Spritpreise als primärer Mobilität-Inhalt ersetzt.
      GoRoute(
        path: '/dashboard/charge-stations',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const ChargeStationsScreen(),
        ),
      ),
      // Spritpreise via Tankerkönig (DE) — Ersatz für Charge-Stations
      // im Mobilität-Modul.
      GoRoute(
        path: '/dashboard/mobility/gas',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const GasPricesScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/jobs',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: ModulePostsScreen(
          title: 'nav.jobs'.tr(),
          emoji: '💼',
          postType: 'job',
          route: '/dashboard/jobs',
          subtitle: 'modules.jobs.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'fulltime', label: '💼 Vollzeit'),
            FilterOption(value: 'parttime', label: '⏰ Teilzeit'),
            FilterOption(value: 'minijob', label: '🔧 Mini-Job'),
            FilterOption(value: 'volunteer', label: '❤️ Ehrenamt'),
          ],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/invite',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const InviteScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/interactions',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const InteractionsScreen(),
        ),
      ),

      // ── Admin (Phase 5) ────────────────────────────────────
      GoRoute(
        path: '/dashboard/admin',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/users',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminUsersScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/posts',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          title: 'admin.tiles.posts'.tr(),
          tableName: 'posts',
          currentRoute: '/dashboard/admin/posts',
          subtitleFields: const ['type', 'category', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/events',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          title: 'admin.tiles.events'.tr(),
          tableName: 'events',
          currentRoute: '/dashboard/admin/events',
          subtitleFields: const ['location_name', 'category'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/board',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          title: 'admin.tiles.board'.tr(),
          tableName: 'board_posts',
          currentRoute: '/dashboard/admin/board',
          subtitleFields: const ['category', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/crisis',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          // FIX R6: Tabelle heisst 'crises', nicht 'crisis_situations'
          title: 'admin.tiles.crisis'.tr(),
          tableName: 'crises',
          currentRoute: '/dashboard/admin/crisis',
          subtitleFields: const ['category', 'urgency', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/organizations',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          title: 'admin.tiles.organizations'.tr(),
          tableName: 'organizations',
          currentRoute: '/dashboard/admin/organizations',
          titleField: 'name',
          subtitleFields: const ['category', 'city', 'is_verified'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/farms',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          // FIX R6: 'is_bio' existiert nicht — verwende 'status' aus farm_listings
          title: 'admin.tiles.farms'.tr(),
          tableName: 'farm_listings',
          currentRoute: '/dashboard/admin/farms',
          titleField: 'name',
          subtitleFields: const ['category', 'address', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/chat-moderation',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminChatModerationScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/groups',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminGroupsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/challenges',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminChallengesScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/timebank',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminZeitbankScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/bot-feedback',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminBotFeedbackScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/contact',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminContactScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/bot-scheduled',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          // FIX R6: korrekte Tabelle ist bot_scheduled_messages
          title: 'admin.tiles.botScheduled'.tr(),
          tableName: 'bot_scheduled_messages',
          currentRoute: '/dashboard/admin/bot-scheduled',
          titleField: 'title',
          subtitleFields: const ['message_type', 'target_audience', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/suggestions',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          // organization_suggestions ist eine echte Tabelle (R6 verifiziert)
          title: 'admin.tiles.suggestions'.tr(),
          tableName: 'organization_suggestions',
          currentRoute: '/dashboard/admin/suggestions',
          titleField: 'name',
          subtitleFields: const ['category', 'city', 'status'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/audit',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: AdminTableScreen(
          // audit_logs Tabelle existiert (R6 verifiziert)
          title: 'admin.tiles.auditLog'.tr(),
          tableName: 'audit_logs',
          currentRoute: '/dashboard/admin/audit',
          titleField: 'action',
          subtitleFields: const ['target_type', 'actor_id'],
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/system',
        pageBuilder: (_, state) => mensaenaTransition<void>(
          key: state.pageKey,
          child: const AdminSystemScreen(),
        ),
      ),
      // Profile-Edit + Saved-Posts werden jetzt als Subroutes unter
      // /dashboard/profile definiert (siehe oben), damit sie vor der
      // :userId-Wildcard matchen. Die alten Top-Level-Definitionen
      // hier wurden entfernt um Routing-Duplikate zu vermeiden.
      // LiveKit Call + Live-Room Screens (DM-Call / Channel-Stream)
      GoRoute(
        path: '/contact-requests',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const ContactRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/community-polls',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const CommunityPollsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/leaderboard',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const LeaderboardScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/my-drafts',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const DraftsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/account',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const AccountScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/karma-history',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const KarmaHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/mentorship',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const MentorshipScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/live/scheduled',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const ScheduledStreamsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/voicemail',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const VoicemailScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/crash-logs',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const AdminCrashLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/scheduled-calls',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const ScheduledCallsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/mentorship/find',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const MentorshipMatchScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/call-history',
        pageBuilder: (_, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: const CallHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/call/:callId',
        pageBuilder: (ctx, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: CallScreen(
          callId: st.pathParameters['callId']!,
          roomName: st.uri.queryParameters['room'] ?? '',
          peerName: st.uri.queryParameters['peer'] ?? 'Anruf',
          // accepted=1 → Callee hat angenommen: direkt verbinden ohne
          // redundanten dm_calls-Status-Query (schnellerer Raum-Eintritt).
          preAccepted: st.uri.queryParameters['accepted'] == '1',
        ),
        ),
      ),
      GoRoute(
        path: '/dashboard/live/:roomName',
        pageBuilder: (ctx, st) => mensaenaTransition<void>(
          key: st.pageKey,
          child: LiveRoomScreen(
          roomName: st.pathParameters['roomName']!,
          channelTitle: st.uri.queryParameters['title'] ?? '',
          isHost: st.uri.queryParameters['host'] == '1',
        ),
        ),
      ),
    ],
    errorBuilder: (context, state) => PlaceholderScreen(
      title: '404',
      phase: 'misc.pageNotFound'.tr(),
    ),
  );
});

GoRoute _placeholder(String path, String title, {String phase = ''}) {
  return GoRoute(
    path: path,
    pageBuilder: (_, state) => mensaenaTransition<void>(
      key: state.pageKey,
      child: PlaceholderScreen(title: title, phase: phase),
    ),
  );
}

/// Alle oeffentlichen Routen — alles ausserhalb wird zu /auth umgeleitet
/// wenn nicht eingeloggt.
const Set<String> _publicRoutes = {
  '/',
  '/onboarding',
  '/about',
  '/spenden',
  '/kontakt',
  '/impressum',
  '/datenschutz',
  '/agb',
  '/haftungsausschluss',
  '/nutzungsbedingungen',
  '/community-guidelines',
  '/download',
  '/search',
  '/unsubscribe',
  '/live-ended',
  '/ratings',
};
