import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/dashboard/board/board_create_screen.dart';
import '../../screens/dashboard/board/board_detail_screen.dart';
import '../../screens/dashboard/board/board_screen.dart';
import '../../screens/dashboard/admin/admin_dashboard_screen.dart';
import '../../screens/dashboard/admin/admin_reports_screen.dart';
import '../../screens/dashboard/admin/admin_system_screen.dart';
import '../../screens/dashboard/admin/admin_table_screen.dart';
import '../../screens/dashboard/admin/admin_users_screen.dart';
import '../../screens/dashboard/badges/badges_screen.dart';
import '../../screens/dashboard/call/call_screen.dart';
import '../../screens/dashboard/live/live_room_screen.dart';
import '../../screens/dashboard/global_search_screen.dart';
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
import '../../screens/dashboard/chat_screen.dart';
import '../../screens/dashboard/create_post_screen.dart';
import '../../screens/dashboard/crisis/crisis_create_screen.dart';
import '../../screens/dashboard/crisis/crisis_dashboard_screen.dart';
import '../../screens/dashboard/crisis/crisis_detail_screen.dart';
import '../../screens/dashboard/crisis/crisis_resources_screen.dart';
import '../../screens/dashboard/dashboard_home_screen.dart';
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
import '../../screens/dashboard/jobs/job_portals_screen.dart';
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
/// Alle Routen der App. Public-Routen sind ohne Login zugaenglich,
/// alle anderen werden bei nicht-Login zu /auth umgeleitet.
/// initialLocation = /splash: Splash-Screen ist der erste Screen.
/// Splash navigiert nach ~1.6s zum Dashboard (wenn eingeloggt) oder /auth.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
      return null;
    },
    routes: <RouteBase>[
      // ── Splash ─────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingTourScreen(),
      ),
      // ── Public ─────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, s) => AuthScreen(
          mode: s.uri.queryParameters['mode'] ?? 'login',
        ),
      ),
      GoRoute(path: '/login', redirect: (_, __) => '/auth?mode=login'),
      GoRoute(path: '/register', redirect: (_, __) => '/auth?mode=register'),
      GoRoute(
        path: '/about',
        builder: (_, __) => const LegalPageScreen(contentKey: 'about'),
      ),
      GoRoute(
        path: '/spenden',
        builder: (_, __) => const SpendenScreen(),
      ),
      GoRoute(
        path: '/kontakt',
        builder: (_, __) => const LegalPageScreen(contentKey: 'kontakt'),
      ),
      GoRoute(
        path: '/impressum',
        builder: (_, __) => const LegalPageScreen(contentKey: 'impressum'),
      ),
      GoRoute(
        path: '/datenschutz',
        builder: (_, __) =>
            const LegalPageScreen(contentKey: 'datenschutz'),
      ),
      GoRoute(
        path: '/agb',
        builder: (_, __) => const LegalPageScreen(contentKey: 'agb'),
      ),
      GoRoute(
        path: '/haftungsausschluss',
        builder: (_, __) =>
            const LegalPageScreen(contentKey: 'haftungsausschluss'),
      ),
      GoRoute(
        path: '/nutzungsbedingungen',
        builder: (_, __) =>
            const LegalPageScreen(contentKey: 'nutzungsbedingungen'),
      ),
      GoRoute(
        path: '/community-guidelines',
        builder: (_, __) =>
            const LegalPageScreen(contentKey: 'community-guidelines'),
      ),
      _placeholder('/download', 'Download'),
      GoRoute(
        path: '/search',
        builder: (_, s) => GlobalSearchScreen(
          initialQuery: s.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/dashboard/search',
        builder: (_, s) => GlobalSearchScreen(
          initialQuery: s.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/unsubscribe',
        builder: (_, s) =>
            UnsubscribeScreen(token: s.uri.queryParameters['token']),
      ),
      _placeholder('/live-ended', 'Session beendet'),
      GoRoute(
        path: '/ratings',
        builder: (_, __) => const RatingsHubScreen(),
      ),

      // ── Dashboard ──────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardHomeScreen(),
      ),
      GoRoute(
        path: '/dashboard/map',
        builder: (_, __) => const MapScreen(),
      ),
      GoRoute(
        path: '/dashboard/create',
        builder: (_, s) => CreatePostScreen(
          initialType: s.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/dashboard/chat',
        builder: (_, s) {
          final conv = s.uri.queryParameters['conv'];
          if (conv != null) {
            return ChatScreen(conversationId: conv);
          }
          return const MessagesScreen(initialTab: 0);
        },
      ),
      GoRoute(
        path: '/dashboard/messages',
        builder: (_, __) => const MessagesScreen(initialTab: 1),
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
        builder: (_, __) => const PostsListScreen(),
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
        builder: (_, __) => const ProfileScreen(),
        routes: [
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
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/dashboard/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      // ── Module-spezifische Create-Pages (1:1 zu Web
      //    /dashboard/<module>/create) ───────────────────────
      GoRoute(
        path: '/dashboard/animals/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.animals),
      ),
      GoRoute(
        path: '/dashboard/housing/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.housing),
      ),
      GoRoute(
        path: '/dashboard/mobility/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.mobility),
      ),
      GoRoute(
        path: '/dashboard/sharing/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.sharing),
      ),
      GoRoute(
        path: '/dashboard/harvest/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.harvest),
      ),
      GoRoute(
        path: '/dashboard/community/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.community),
      ),
      // Wissen/Wiki nutzt eigenes Schema `knowledge_articles`
      // (kein posts-Entry) — daher dedicated Create-Screen.
      GoRoute(
        path: '/dashboard/knowledge/create',
        builder: (_, __) => const KnowledgeCreateScreen(
            routePath: '/dashboard/knowledge'),
      ),
      GoRoute(
        path: '/dashboard/wiki/create',
        builder: (_, __) => const KnowledgeCreateScreen(
            routePath: '/dashboard/wiki'),
      ),
      GoRoute(
        path: '/dashboard/skills/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.skills),
      ),
      GoRoute(
        path: '/dashboard/jobs/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.jobs),
      ),
      GoRoute(
        path: '/dashboard/rescuer/create',
        builder: (_, __) => const ModuleCreatePostScreen(
            config: ModuleCreateConfigs.rescuer),
      ),
      GoRoute(
        path: '/dashboard/animals',
        builder: (_, __) => ModulePostsScreen(
          title: 'nav.animals'.tr(),
          emoji: '🐾',
          postType: 'animal',
          route: '/dashboard/animals',
          subtitle: 'modules.animals.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'lost', label: '😢 Vermisst'),
            FilterOption(value: 'found', label: '🔍 Gefunden'),
            FilterOption(value: 'care', label: '🏠 Pflege'),
            FilterOption(value: 'adoption', label: '❤️ Adoption'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/housing',
        builder: (_, __) => ModulePostsScreen(
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
      GoRoute(
        path: '/dashboard/mobility',
        builder: (_, __) => ModulePostsScreen(
          title: 'nav.mobility'.tr(),
          emoji: '🚗',
          postType: 'mobility',
          route: '/dashboard/mobility',
          subtitle: 'modules.mobility.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'rideshare', label: '🚗 Mitfahrt'),
            FilterOption(value: 'carpool', label: '👥 Fahrgemeinschaft'),
            FilterOption(value: 'transport', label: '📦 Transport'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/harvest',
        builder: (_, __) => ModulePostsScreen(
          title: 'nav.harvest'.tr(),
          emoji: '🌾',
          postType: 'supply',
          route: '/dashboard/harvest',
          subtitle: 'modules.harvest.subtitle'.tr(),
          subFilters: const [
            FilterOption(value: 'fruit', label: '🍎 Obst'),
            FilterOption(value: 'vegetable', label: '🥕 Gemüse'),
            FilterOption(value: 'herbs', label: '🌿 Kräuter'),
            FilterOption(value: 'eggs', label: '🥚 Eier/Milch'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/community',
        builder: (_, __) => ModulePostsScreen(
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
      GoRoute(
        path: '/dashboard/wiki',
        builder: (_, __) => KnowledgeScreen(
          title: 'modules.wiki'.tr(),
          routePath: '/dashboard/wiki',
        ),
      ),
      GoRoute(
        path: '/dashboard/knowledge',
        builder: (_, __) => KnowledgeScreen(
          title: 'nav.knowledge'.tr(),
          routePath: '/dashboard/knowledge',
        ),
      ),
      GoRoute(
        path: '/dashboard/groups',
        builder: (_, __) => const GroupsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const GroupCreateScreen(),
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
        builder: (_, __) => const MarketplaceScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const MarketplaceCreateScreen(),
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
        builder: (_, __) => const EventsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const EventCreateScreen(),
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
        builder: (_, __) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/dashboard/challenges',
        builder: (_, __) => const ChallengesScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const ChallengeCreateScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/badges',
        builder: (_, __) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/dashboard/timebank',
        builder: (_, __) => const TimebankScreen(),
      ),
      GoRoute(
        path: '/dashboard/skills',
        builder: (_, __) => const SkillsScreen(),
      ),
      // Modul-Audit Sprint 2 — Hub-Routes konsolidieren 3+3 Drawer-Items.
      GoRoute(
        path: '/dashboard/wissen',
        builder: (_, __) => const WissenHubScreen(),
      ),
      GoRoute(
        path: '/dashboard/teilen',
        builder: (_, __) => const TeilenHubScreen(),
      ),
      GoRoute(
        path: '/dashboard/organizations',
        builder: (_, __) => const OrganizationsScreen(),
        routes: [
          GoRoute(
            path: 'suggest',
            builder: (_, __) => const OrganizationSuggestScreen(),
          ),
          GoRoute(
            path: ':orgId',
            builder: (_, s) => OrganizationDetailScreen(
              orgId: s.pathParameters['orgId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/supply',
        builder: (_, __) => const SupplyScreen(),
        routes: [
          GoRoute(
            path: 'farm/add',
            builder: (_, __) => const FarmCreateScreen(),
          ),
          GoRoute(
            path: 'foodbanks',
            builder: (_, __) => const FoodbanksScreen(),
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
        builder: (_, __) => const CrisisDashboardScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const CrisisCreateScreen(),
          ),
          GoRoute(
            path: 'resources',
            builder: (_, __) => const CrisisResourcesScreen(),
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
        builder: (_, __) => const WarnungenScreen(),
        routes: [
          GoRoute(
            path: 'food',
            builder: (_, __) => const FoodWarningsScreen(),
          ),
          GoRoute(
            path: 'air',
            builder: (_, __) => const AirQualityScreen(),
          ),
          GoRoute(
            path: 'meteo',
            builder: (_, __) => const MeteoAlarmScreen(),
          ),
          GoRoute(
            path: 'civil',
            builder: (_, __) => const CivilProtectionScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/board',
        builder: (_, __) => const BoardScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const BoardCreateScreen(),
          ),
          GoRoute(
            path: ':boardPostId',
            builder: (_, s) => BoardDetailScreen(
              boardPostId: s.pathParameters['boardPostId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/mental-support',
        builder: (_, __) => const MentalSupportScreen(),
      ),
      GoRoute(
        path: '/dashboard/matching',
        builder: (_, __) => const MatchingScreen(),
      ),
      GoRoute(
        path: '/dashboard/rescuer',
        builder: (_, __) => ModulePostsScreen(
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
      GoRoute(
        path: '/dashboard/sharing',
        builder: (_, __) => ModulePostsScreen(
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
      GoRoute(
        path: '/dashboard/jobs-portals',
        builder: (_, __) => const JobPortalsScreen(),
      ),
      GoRoute(
        path: '/dashboard/jobs',
        builder: (_, __) => ModulePostsScreen(
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
      GoRoute(
        path: '/dashboard/invite',
        builder: (_, __) => const InviteScreen(),
      ),
      GoRoute(
        path: '/dashboard/interactions',
        builder: (_, __) => const InteractionsScreen(),
      ),

      // ── Admin (Phase 5) ────────────────────────────────────
      GoRoute(
        path: '/dashboard/admin',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/users',
        builder: (_, __) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/posts',
        builder: (_, __) => AdminTableScreen(
          title: 'admin.tiles.posts'.tr(),
          tableName: 'posts',
          currentRoute: '/dashboard/admin/posts',
          subtitleFields: const ['type', 'category', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/events',
        builder: (_, __) => AdminTableScreen(
          title: 'admin.tiles.events'.tr(),
          tableName: 'events',
          currentRoute: '/dashboard/admin/events',
          subtitleFields: const ['location_name', 'category'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/board',
        builder: (_, __) => AdminTableScreen(
          title: 'admin.tiles.board'.tr(),
          tableName: 'board_posts',
          currentRoute: '/dashboard/admin/board',
          subtitleFields: const ['category', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/crisis',
        builder: (_, __) => AdminTableScreen(
          // FIX R6: Tabelle heisst 'crises', nicht 'crisis_situations'
          title: 'admin.tiles.crisis'.tr(),
          tableName: 'crises',
          currentRoute: '/dashboard/admin/crisis',
          subtitleFields: const ['category', 'urgency', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/organizations',
        builder: (_, __) => AdminTableScreen(
          title: 'admin.tiles.organizations'.tr(),
          tableName: 'organizations',
          currentRoute: '/dashboard/admin/organizations',
          titleField: 'name',
          subtitleFields: const ['category', 'city', 'is_verified'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/farms',
        builder: (_, __) => AdminTableScreen(
          // FIX R6: 'is_bio' existiert nicht — verwende 'status' aus farm_listings
          title: 'admin.tiles.farms'.tr(),
          tableName: 'farm_listings',
          currentRoute: '/dashboard/admin/farms',
          titleField: 'name',
          subtitleFields: const ['category', 'address', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/chat-moderation',
        builder: (_, __) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/groups',
        builder: (_, __) => AdminTableScreen(
          title: 'admin.tiles.groups'.tr(),
          tableName: 'groups',
          currentRoute: '/dashboard/admin/groups',
          titleField: 'name',
          subtitleFields: const ['category', 'is_private'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/challenges',
        builder: (_, __) => AdminTableScreen(
          // FIX R6: Spalten aus challenges-Schema (category/difficulty/points)
          title: 'admin.tiles.challenges'.tr(),
          tableName: 'challenges',
          currentRoute: '/dashboard/admin/challenges',
          subtitleFields: const ['category', 'difficulty', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/timebank',
        builder: (_, __) => AdminTableScreen(
          // FIX R6: timebank_entries hat type/hours, KEINE status-Spalte
          title: 'admin.tiles.timebank'.tr(),
          tableName: 'timebank_entries',
          currentRoute: '/dashboard/admin/timebank',
          titleField: 'description',
          subtitleFields: const ['type', 'hours'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/bot-scheduled',
        builder: (_, __) => AdminTableScreen(
          // FIX R6: korrekte Tabelle ist bot_scheduled_messages
          title: 'admin.tiles.botScheduled'.tr(),
          tableName: 'bot_scheduled_messages',
          currentRoute: '/dashboard/admin/bot-scheduled',
          titleField: 'title',
          subtitleFields: const ['message_type', 'target_audience', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/suggestions',
        builder: (_, __) => AdminTableScreen(
          // organization_suggestions ist eine echte Tabelle (R6 verifiziert)
          title: 'admin.tiles.suggestions'.tr(),
          tableName: 'organization_suggestions',
          currentRoute: '/dashboard/admin/suggestions',
          titleField: 'name',
          subtitleFields: const ['category', 'city', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/audit',
        builder: (_, __) => AdminTableScreen(
          // audit_logs Tabelle existiert (R6 verifiziert)
          title: 'admin.tiles.auditLog'.tr(),
          tableName: 'audit_logs',
          currentRoute: '/dashboard/admin/audit',
          titleField: 'action',
          subtitleFields: const ['target_type', 'actor_id'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/system',
        builder: (_, __) => const AdminSystemScreen(),
      ),
      // Profile-Edit + Saved-Posts
      GoRoute(
        path: '/dashboard/profile/edit',
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/dashboard/profile/saved',
        builder: (_, __) => const ProfileSavedScreen(),
      ),
      // LiveKit Call + Live-Room Screens (DM-Call / Channel-Stream)
      GoRoute(
        path: '/dashboard/call/:callId',
        builder: (ctx, st) => CallScreen(
          callId: st.pathParameters['callId']!,
          roomName: st.uri.queryParameters['room'] ?? '',
          peerName: st.uri.queryParameters['peer'] ?? 'Anruf',
        ),
      ),
      GoRoute(
        path: '/dashboard/live/:roomName',
        builder: (ctx, st) => LiveRoomScreen(
          roomName: st.pathParameters['roomName']!,
          channelTitle: st.uri.queryParameters['title'] ?? '',
          isHost: st.uri.queryParameters['host'] == '1',
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
    builder: (_, __) => PlaceholderScreen(title: title, phase: phase),
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
