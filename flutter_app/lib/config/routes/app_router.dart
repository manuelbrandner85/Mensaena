import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/dashboard/board/board_create_screen.dart';
import '../../screens/dashboard/board/board_detail_screen.dart';
import '../../screens/dashboard/board/board_screen.dart';
import '../../screens/dashboard/calendar_screen.dart';
import '../../screens/dashboard/groups/group_create_screen.dart';
import '../../screens/dashboard/groups/group_detail_screen.dart';
import '../../screens/dashboard/groups/groups_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_create_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_detail_screen.dart';
import '../../screens/dashboard/marketplace/marketplace_screen.dart';
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
import '../../screens/dashboard/events/event_create_screen.dart';
import '../../screens/dashboard/events/event_detail_screen.dart';
import '../../screens/dashboard/events/events_screen.dart';
import '../../screens/dashboard/interactions_screen.dart';
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
import '../../services/supabase_service.dart';

/// SKILL: flutter-setup-declarative-routing
/// Alle Routen der App. Public-Routen sind ohne Login zugaenglich,
/// alle anderen werden bei nicht-Login zu /auth umgeleitet.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final loggedIn = SupabaseService.isLoggedIn;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/auth' || loc == '/login' || loc == '/register';
      final isPublic = _publicRoutes.any(
        (p) => loc == p || loc.startsWith('$p/'),
      );

      if (!loggedIn && !isAuthRoute && !isPublic) {
        return '/auth?mode=login';
      }
      if (loggedIn && isAuthRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: <RouteBase>[
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
      _placeholder('/dashboard/animals', 'Tiere', phase: 'Phase 4'),
      _placeholder('/dashboard/housing', 'Wohnen', phase: 'Phase 4'),
      _placeholder('/dashboard/mobility', 'Mobilitaet', phase: 'Phase 4'),
      _placeholder('/dashboard/harvest', 'Ernte', phase: 'Phase 4'),
      _placeholder('/dashboard/community', 'Community', phase: 'Phase 4'),
      _placeholder('/dashboard/wiki', 'Wiki', phase: 'Phase 4'),
      _placeholder('/dashboard/knowledge', 'Wissen', phase: 'Phase 4'),
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
      _placeholder('/dashboard/challenges', 'Challenges', phase: 'Phase 4'),
      _placeholder('/dashboard/badges', 'Badges', phase: 'Phase 4'),
      GoRoute(
        path: '/dashboard/timebank',
        builder: (_, __) => const TimebankScreen(),
      ),
      _placeholder('/dashboard/skills', 'Skills', phase: 'Phase 4'),
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
      _placeholder(
        '/dashboard/mental-support',
        'Mentale Unterstuetzung',
        phase: 'Phase 4',
      ),
      _placeholder('/dashboard/matching', 'Matching', phase: 'Phase 4'),
      _placeholder('/dashboard/rescuer', 'Rettung', phase: 'Phase 4'),
      _placeholder('/dashboard/sharing', 'Teilen', phase: 'Phase 4'),
      _placeholder('/dashboard/jobs', 'Jobs', phase: 'Phase 4'),
      _placeholder('/dashboard/invite', 'Einladen', phase: 'Phase 4'),
      GoRoute(
        path: '/dashboard/interactions',
        builder: (_, __) => const InteractionsScreen(),
      ),

      // ── Admin ──────────────────────────────────────────────
      _placeholder('/dashboard/admin', 'Admin', phase: 'Phase 5'),
      _placeholder(
        '/dashboard/admin/users',
        'Admin: Users',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/posts',
        'Admin: Posts',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/events',
        'Admin: Events',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/board',
        'Admin: Board',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/crisis',
        'Admin: Krise',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/organizations',
        'Admin: Orgs',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/farms',
        'Admin: Farms',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/chat-moderation',
        'Admin: Chat-Mod',
        phase: 'Phase 5',
      ),
      _placeholder(
        '/dashboard/admin/system',
        'Admin: System',
        phase: 'Phase 5',
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
