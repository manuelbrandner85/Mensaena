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
import '../../screens/dashboard/calendar_screen.dart';
import '../../screens/dashboard/challenges/challenges_screen.dart';
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
import '../../screens/dashboard/supply/farm_detail_screen.dart';
import '../../screens/dashboard/supply/supply_screen.dart';
import '../../screens/dashboard/chat_screen.dart';
import '../../screens/dashboard/create_post_screen.dart';
import '../../screens/dashboard/crisis/crisis_create_screen.dart';
import '../../screens/dashboard/crisis/crisis_dashboard_screen.dart';
import '../../screens/dashboard/crisis/crisis_detail_screen.dart';
import '../../screens/dashboard/crisis/crisis_resources_screen.dart';
import '../../screens/dashboard/dashboard_home_screen.dart';
import '../../screens/dashboard/knowledge/knowledge_screen.dart';
import '../../screens/dashboard/module/module_posts_screen.dart';
import '../../screens/dashboard/skills/skills_screen.dart';
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
import '../../screens/dashboard/settings_screen.dart';
import '../../screens/dashboard/timebank_screen.dart';
import '../../screens/dashboard/warnungen/food_warnings_screen.dart';
import '../../screens/dashboard/warnungen/warnungen_screen.dart';
import '../../screens/misc/placeholder_screen.dart';
import '../../screens/public/auth_screen.dart';
import '../../screens/public/landing_screen.dart';
import '../../screens/public/splash_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/shared/filter_chip_bar.dart';

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
      _placeholder('/about', 'Über uns'),
      _placeholder('/spenden', 'Spenden'),
      _placeholder('/kontakt', 'Kontakt'),
      _placeholder('/impressum', 'Impressum'),
      _placeholder('/datenschutz', 'Datenschutz'),
      _placeholder('/agb', 'AGB'),
      _placeholder('/haftungsausschluss', 'Haftungsausschluss'),
      _placeholder('/nutzungsbedingungen', 'Nutzungsbedingungen'),
      _placeholder('/community-guidelines', 'Community-Guidelines'),
      _placeholder('/download', 'Download'),
      _placeholder('/search', 'Suche'),
      _placeholder('/unsubscribe', 'Abmeldung'),
      _placeholder('/live-ended', 'Session beendet'),
      _placeholder('/ratings', 'Bewertungen'),

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
          return const MessagesScreen();
        },
      ),
      GoRoute(
        path: '/dashboard/messages',
        builder: (_, __) => const MessagesScreen(),
        routes: [
          GoRoute(
            path: ':conversationId',
            builder: (_, s) => ChatScreen(
              conversationId: s.pathParameters['conversationId']!,
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
            builder: (_, s) =>
                PostDetailScreen(postId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard/profile',
        builder: (_, __) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: ':userId',
            builder: (_, s) =>
                ProfileScreen(userId: s.pathParameters['userId']),
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
      GoRoute(
        path: '/dashboard/animals',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Tiere',
          emoji: '🐾',
          postType: 'animal',
          route: '/dashboard/animals',
          subtitle: 'Tierhilfe, Fundtiere, Pflegestellen',
          subFilters: [
            FilterOption(value: 'lost', label: '😢 Vermisst'),
            FilterOption(value: 'found', label: '🔍 Gefunden'),
            FilterOption(value: 'care', label: '🏠 Pflege'),
            FilterOption(value: 'adoption', label: '❤️ Adoption'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/housing',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Wohnen',
          emoji: '🏡',
          postType: 'housing',
          route: '/dashboard/housing',
          subtitle: 'Wohnungen, WG-Zimmer, Mitwohnen',
          subFilters: [
            FilterOption(value: 'seeking', label: '🔍 Suche'),
            FilterOption(value: 'offering', label: '🎁 Biete'),
            FilterOption(value: 'wg', label: '🏠 WG'),
            FilterOption(value: 'emergency', label: '🚨 Notunterkunft'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/mobility',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Mobilität',
          emoji: '🚗',
          postType: 'mobility',
          route: '/dashboard/mobility',
          subtitle: 'Mitfahrten, Carsharing, Transport',
          subFilters: [
            FilterOption(value: 'rideshare', label: '🚗 Mitfahrt'),
            FilterOption(value: 'carpool', label: '👥 Fahrgemeinschaft'),
            FilterOption(value: 'transport', label: '📦 Transport'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/harvest',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Ernte',
          emoji: '🌾',
          postType: 'supply',
          route: '/dashboard/harvest',
          subtitle: 'Obst, Gemüse, Garten-Ernte teilen',
          subFilters: [
            FilterOption(value: 'fruit', label: '🍎 Obst'),
            FilterOption(value: 'vegetable', label: '🥕 Gemüse'),
            FilterOption(value: 'herbs', label: '🌿 Kräuter'),
            FilterOption(value: 'eggs', label: '🥚 Eier/Milch'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/community',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Community',
          emoji: '🗳️',
          postType: 'community',
          route: '/dashboard/community',
          subtitle: 'Diskussionen, Treffen, Nachbarschaft',
          subFilters: [
            FilterOption(value: 'discussion', label: '💬 Diskussion'),
            FilterOption(value: 'meeting', label: '👥 Treffen'),
            FilterOption(value: 'announcement', label: '📣 Ankündigung'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/wiki',
        builder: (_, __) => const KnowledgeScreen(
          title: 'Wiki',
          routePath: '/dashboard/wiki',
        ),
      ),
      GoRoute(
        path: '/dashboard/knowledge',
        builder: (_, __) => const KnowledgeScreen(
          title: 'Wissen',
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
            builder: (_, s) => GroupDetailScreen(
              groupId: s.pathParameters['groupId']!,
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
            builder: (_, s) => MarketplaceDetailScreen(
              listingId: s.pathParameters['listingId']!,
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
            builder: (_, s) => EventDetailScreen(
              eventId: s.pathParameters['eventId']!,
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
            path: ':slug',
            builder: (_, s) => FarmDetailScreen(
              slug: s.pathParameters['slug']!,
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
            builder: (_, s) => CrisisDetailScreen(
              crisisId: s.pathParameters['crisisId']!,
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
        builder: (_, __) => const ModulePostsScreen(
          title: 'Rettung',
          emoji: '🛟',
          postType: 'rescue',
          route: '/dashboard/rescuer',
          subtitle: 'Geretttete Lebensmittel, Kleidung, Gegenstände',
          subFilters: [
            FilterOption(value: 'food', label: '🍎 Lebensmittel'),
            FilterOption(value: 'everyday', label: '👕 Kleidung'),
            FilterOption(value: 'sharing', label: '📦 Gegenstände'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/sharing',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Teilen',
          emoji: '🔄',
          postType: 'sharing',
          route: '/dashboard/sharing',
          subtitle: 'Werkzeug, Bücher, Geräte verleihen',
          subFilters: [
            FilterOption(value: 'tools', label: '🔧 Werkzeug'),
            FilterOption(value: 'books', label: '📚 Bücher'),
            FilterOption(value: 'devices', label: '📱 Geräte'),
            FilterOption(value: 'kitchen', label: '🍴 Küche'),
            FilterOption(value: 'sports', label: '⚽ Sport'),
          ],
        ),
      ),
      GoRoute(
        path: '/dashboard/jobs',
        builder: (_, __) => const ModulePostsScreen(
          title: 'Jobs',
          emoji: '💼',
          postType: 'job',
          route: '/dashboard/jobs',
          subtitle: 'Stellen, Mini-Jobs, ehrenamtliche Tätigkeiten',
          subFilters: [
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
        builder: (_, __) => const AdminTableScreen(
          title: 'Posts',
          tableName: 'posts',
          currentRoute: '/dashboard/admin/posts',
          subtitleFields: ['type', 'category', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/events',
        builder: (_, __) => const AdminTableScreen(
          title: 'Events',
          tableName: 'events',
          currentRoute: '/dashboard/admin/events',
          subtitleFields: ['location_name', 'category'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/board',
        builder: (_, __) => const AdminTableScreen(
          title: 'Board',
          tableName: 'board_posts',
          currentRoute: '/dashboard/admin/board',
          subtitleFields: ['category', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/crisis',
        builder: (_, __) => const AdminTableScreen(
          title: 'Krisen',
          tableName: 'crisis_situations',
          currentRoute: '/dashboard/admin/crisis',
          subtitleFields: ['severity', 'status', 'crisis_type'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/organizations',
        builder: (_, __) => const AdminTableScreen(
          title: 'Organisationen',
          tableName: 'organizations',
          currentRoute: '/dashboard/admin/organizations',
          titleField: 'name',
          subtitleFields: ['category', 'city', 'is_verified'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/farms',
        builder: (_, __) => const AdminTableScreen(
          title: 'Farms',
          tableName: 'farm_listings',
          currentRoute: '/dashboard/admin/farms',
          titleField: 'name',
          subtitleFields: ['category', 'city', 'is_bio'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/chat-moderation',
        builder: (_, __) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/groups',
        builder: (_, __) => const AdminTableScreen(
          title: 'Groups',
          tableName: 'groups',
          currentRoute: '/dashboard/admin/groups',
          titleField: 'name',
          subtitleFields: ['category', 'is_private'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/challenges',
        builder: (_, __) => const AdminTableScreen(
          title: 'Challenges',
          tableName: 'challenges',
          currentRoute: '/dashboard/admin/challenges',
          subtitleFields: ['type', 'target_count', 'is_active'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/timebank',
        builder: (_, __) => const AdminTableScreen(
          title: 'Zeitbank',
          tableName: 'timebank_entries',
          currentRoute: '/dashboard/admin/timebank',
          titleField: 'description',
          subtitleFields: ['category', 'hours', 'status'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/contact',
        builder: (_, __) => const AdminTableScreen(
          title: 'Kontakt-Anfragen',
          tableName: 'contact_messages',
          currentRoute: '/dashboard/admin/contact',
          titleField: 'subject',
          subtitleFields: ['email', 'status', 'category'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/bot-feedback',
        builder: (_, __) => const AdminTableScreen(
          title: 'Bot Feedback',
          tableName: 'bot_feedback',
          currentRoute: '/dashboard/admin/bot-feedback',
          titleField: 'message',
          subtitleFields: ['rating', 'category'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/marketing',
        builder: (_, __) => const AdminTableScreen(
          title: 'Marketing',
          tableName: 'marketing_campaigns',
          currentRoute: '/dashboard/admin/marketing',
          titleField: 'name',
          subtitleFields: ['status', 'sent_count'],
        ),
      ),
      GoRoute(
        path: '/dashboard/admin/system',
        builder: (_, __) => const AdminSystemScreen(),
      ),
    ],
    errorBuilder: (context, state) => const PlaceholderScreen(
      title: '404',
      phase: 'Seite nicht gefunden',
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
