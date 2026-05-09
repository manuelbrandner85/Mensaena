import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase.dart';
import '../features/admin/admin_page.dart';
import '../features/animals/animals_page.dart';
import '../features/auth/auth_page.dart';
import '../features/badges/badges_page.dart';
import '../features/board/board_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/challenges/challenges_page.dart';
import '../features/chat/chat_page.dart';
import '../features/crisis/crisis_create_page.dart';
import '../features/crisis/crisis_detail_page.dart';
import '../features/crisis/crisis_page.dart';
import '../features/crisis/crisis_resources_page.dart';
import '../features/mental_support/mental_support_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/events/event_detail_page.dart';
import '../features/events/events_page.dart';
import '../features/groups/group_detail_page.dart';
import '../features/groups/groups_page.dart';
import '../features/interactions/interactions_page.dart';
import '../features/invite/invite_page.dart';
import '../features/jobs/jobs_page.dart';
import '../features/landing/landing_page.dart';
import '../features/marketplace/marketplace_create_page.dart';
import '../features/marketplace/marketplace_detail_page.dart';
import '../features/marketplace/marketplace_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/public_profile_page.dart';
import '../features/settings/settings_page.dart';
import '../features/timebank/timebank_page.dart';
import '../features/wiki/wiki_page.dart';
import '../features/legal/legal_pages.dart';
import '../features/live_ended/live_ended_page.dart';
import '../features/map/map_page.dart';
import '../features/matching/matching_page.dart';
import '../features/messages/conversation_page.dart';
import '../features/messages/messages_page.dart';
import '../features/organizations/organization_detail_page.dart';
import '../features/organizations/organization_suggest_page.dart';
import '../features/organizations/organizations_page.dart';
import '../features/posts/create_post_page.dart';
import '../features/posts/post_detail_page.dart';
import '../features/posts/posts_page.dart';
import '../features/search/search_page.dart';
import '../navigation/app_shell.dart';
import 'routes.dart';
import 'stub_pages.dart';

/// Globaler Router – Pendant zum Next.js-App-Router.
/// Auth-Guard entspricht middleware.ts: nicht authentifizierte Nutzer
/// auf öffentlichen Routen werden bei Dashboard-Zugriff zu /auth umgeleitet.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.dashboard,
    debugLogDiagnostics: true,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final loggedIn = sb.auth.currentSession != null;
      final isAuthRoute = state.matchedLocation == Routes.auth ||
          state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register;
      final isPublic = _publicRoutes.contains(state.matchedLocation);

      if (!loggedIn && !isAuthRoute && !isPublic) {
        return '${Routes.auth}?mode=login';
      }
      if (loggedIn && isAuthRoute) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: [
      // ── Public / Auth ───────────────────────────────────────
      GoRoute(path: Routes.root, redirect: (_, __) => Routes.dashboard),
      GoRoute(path: Routes.landing, builder: (_, __) => const LandingPage()),
      GoRoute(
        path: Routes.auth,
        builder: (_, s) => AuthPage(
          mode: s.uri.queryParameters['mode'] ?? 'login',
          referralCode: s.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(path: Routes.login, redirect: (_, __) => '${Routes.auth}?mode=login'),
      GoRoute(path: Routes.register, redirect: (_, __) => '${Routes.auth}?mode=register'),
      GoRoute(path: Routes.download, builder: (_, __) => const StubPage(title: 'Download')),
      GoRoute(path: Routes.search, builder: (_, __) => const SearchPage()),
      GoRoute(path: Routes.spenden, builder: (_, __) => const StubPage(title: 'Spenden')),
      GoRoute(path: Routes.unsubscribe, builder: (_, __) => const StubPage(title: 'Unsubscribe')),
      GoRoute(path: Routes.liveEnded, builder: (_, __) => const LiveEndedPage()),
      GoRoute(path: Routes.app, redirect: (_, __) => Routes.dashboard),

      // ── Legal ───────────────────────────────────────────────
      GoRoute(path: Routes.about, builder: (_, __) => const AboutPage()),
      GoRoute(path: Routes.agb, builder: (_, __) => const AgbPage()),
      GoRoute(path: Routes.datenschutz, builder: (_, __) => const DatenschutzPage()),
      GoRoute(path: Routes.impressum, builder: (_, __) => const ImpressumPage()),
      GoRoute(path: Routes.kontakt, builder: (_, __) => const KontaktPage()),
      GoRoute(path: Routes.haftungsausschluss, builder: (_, __) => const HaftungsausschlussPage()),
      GoRoute(path: Routes.nutzungsbedingungen, builder: (_, __) => const NutzungsbedingungenPage()),
      GoRoute(path: Routes.communityGuidelines, builder: (_, __) => const CommunityGuidelinesPage()),

      // ── Dashboard (mit AppShell – BottomNav, Sidebar, Topbar) ──
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.dashboard, builder: (_, __) => const DashboardPage()),
          GoRoute(
            path: Routes.dashboardCreate,
            builder: (_, s) {
              final type = s.uri.queryParameters['type'];
              if (type == 'post') return const CreatePostPage();
              return const StubPage(title: 'Erstellen');
            },
          ),
          GoRoute(path: Routes.dashboardNotifications, builder: (_, __) => const NotificationsPage()),
          GoRoute(
            path: Routes.dashboardMessages,
            builder: (_, __) => const MessagesPage(),
            routes: [
              GoRoute(
                path: ':conversationId',
                builder: (_, s) =>
                    ConversationPage(conversationId: s.pathParameters['conversationId']!),
              ),
            ],
          ),
          GoRoute(path: Routes.dashboardChat, builder: (_, __) => const ChatPage()),
          GoRoute(path: Routes.dashboardMatching, builder: (_, __) => const MatchingPage()),
          GoRoute(path: Routes.dashboardMap, builder: (_, __) => const MapPage()),
          GoRoute(path: Routes.dashboardPosts, builder: (_, __) => const PostsPage()),
          GoRoute(
            path: '${Routes.dashboardPosts}/:id',
            builder: (_, s) => PostDetailPage(postId: s.pathParameters['id']!),
          ),
          GoRoute(path: Routes.dashboardOrganizations, builder: (_, __) => const OrganizationsPage()),
          GoRoute(path: Routes.dashboardOrganizationsSuggest, builder: (_, __) => const OrganizationSuggestPage()),
          GoRoute(
            path: '${Routes.dashboardOrganizations}/:orgId',
            builder: (_, s) => OrganizationDetailPage(idOrSlug: s.pathParameters['orgId']!),
          ),
          GoRoute(path: Routes.dashboardInteractions, builder: (_, __) => const InteractionsPage()),
          GoRoute(path: '${Routes.dashboardInteractions}/:interactionId', builder: (_, s) => StubPage(title: 'Interaktion ${s.pathParameters['interactionId']}')),
          GoRoute(path: Routes.dashboardAnimals, builder: (_, __) => const AnimalsPage()),
          GoRoute(
            path: Routes.dashboardAnimalsCreate,
            builder: (_, __) => const CreatePostPage(),
          ),
          GoRoute(path: Routes.dashboardCrisis, builder: (_, __) => const CrisisPage()),
          GoRoute(path: Routes.dashboardCrisisCreate, builder: (_, __) => const CrisisCreatePage()),
          GoRoute(path: Routes.dashboardCrisisResources, builder: (_, __) => const CrisisResourcesPage()),
          GoRoute(
            path: '${Routes.dashboardCrisis}/:crisisId',
            builder: (_, s) => CrisisDetailPage(crisisId: s.pathParameters['crisisId']!),
          ),
          GoRoute(path: Routes.dashboardMentalSupport, builder: (_, __) => const MentalSupportPage()),
          GoRoute(path: Routes.dashboardMentalSupportCreate, builder: (_, __) => const StubPage(title: 'Mental-Support erstellen')),
          GoRoute(path: Routes.dashboardGroups, builder: (_, __) => const GroupsPage()),
          GoRoute(path: Routes.dashboardGroupsCreate, builder: (_, __) => const StubPage(title: 'Gruppe erstellen')),
          GoRoute(
            path: '${Routes.dashboardGroups}/:groupId',
            builder: (_, s) =>
                GroupDetailPage(idOrSlug: s.pathParameters['groupId']!),
          ),
          GoRoute(path: Routes.dashboardEvents, builder: (_, __) => const EventsPage()),
          GoRoute(path: Routes.dashboardEventsCreate, builder: (_, __) => const StubPage(title: 'Event erstellen')),
          GoRoute(
            path: '${Routes.dashboardEvents}/:id',
            builder: (_, s) =>
                EventDetailPage(eventId: s.pathParameters['id']!),
          ),
          GoRoute(path: Routes.dashboardBoard, builder: (_, __) => const BoardPage()),
          GoRoute(path: Routes.dashboardChallenges, builder: (_, __) => const ChallengesPage()),
          GoRoute(path: Routes.dashboardChallengesCreate, builder: (_, __) => const StubPage(title: 'Challenge erstellen')),
          // Phase 5: Listing-Module – die meisten sind themed-Wrapper
          // um PostsPage mit fixiertem type-Filter; jobs/marketplace/timebank
          // haben eigene Pages.
          GoRoute(path: Routes.dashboardSharing, builder: (_, __) => const PostsPage(title: 'Teilen', initialType: 'sharing', lockType: true)),
          GoRoute(path: Routes.dashboardSharingCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardTimebank, builder: (_, __) => const TimebankPage()),
          GoRoute(path: Routes.dashboardMarketplace, builder: (_, __) => const MarketplacePage()),
          GoRoute(path: Routes.dashboardMarketplaceCreate, builder: (_, __) => const MarketplaceCreatePage()),
          GoRoute(
            path: '${Routes.dashboardMarketplace}/:id',
            builder: (_, s) => MarketplaceDetailPage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: Routes.dashboardSupply, builder: (_, __) => const PostsPage(title: 'Versorgung', initialType: 'supply', lockType: true)),
          GoRoute(path: '${Routes.dashboardSupply}/farm/:slug', builder: (_, s) => StubPage(title: 'Farm ${s.pathParameters['slug']}')),
          GoRoute(path: Routes.dashboardSupplyFarmAdd, builder: (_, __) => const StubPage(title: 'Farm hinzufügen')),
          GoRoute(path: Routes.dashboardHarvest, builder: (_, __) => const PostsPage(title: 'Ernte', initialType: 'supply', lockType: true)),
          GoRoute(path: Routes.dashboardHarvestCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardRescuer, builder: (_, __) => const PostsPage(title: 'Lebensretter', initialType: 'rescue', lockType: true)),
          GoRoute(path: Routes.dashboardRescuerCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardHousing, builder: (_, __) => const PostsPage(title: 'Wohnen', initialType: 'housing', lockType: true)),
          GoRoute(path: Routes.dashboardHousingCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardMobility, builder: (_, __) => const PostsPage(title: 'Mobilität', initialType: 'mobility', lockType: true)),
          GoRoute(path: Routes.dashboardMobilityCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardJobs, builder: (_, __) => const JobsPage()),
          GoRoute(path: Routes.dashboardWiki, builder: (_, __) => const WikiPage()),
          GoRoute(path: Routes.dashboardWikiCreate, builder: (_, __) => const StubPage(title: 'Wiki-Eintrag')),
          GoRoute(path: Routes.dashboardKnowledge, builder: (_, __) => const PostsPage(title: 'Bildung & Wissen', initialType: 'community', lockType: false)),
          GoRoute(path: Routes.dashboardKnowledgeCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardSkills, builder: (_, __) => const PostsPage(title: 'Skills', initialType: 'sharing', lockType: false)),
          GoRoute(path: Routes.dashboardSkillsCreate, builder: (_, __) => const CreatePostPage()),
          GoRoute(path: Routes.dashboardCalendar, builder: (_, __) => const CalendarPage()),
          GoRoute(path: Routes.dashboardCommunity, builder: (_, __) => const StubPage(title: 'Community')),
          GoRoute(path: Routes.dashboardCommunityCreate, builder: (_, __) => const StubPage(title: 'Community erstellen')),
          GoRoute(path: Routes.dashboardProfile, builder: (_, __) => const ProfilePage()),
          GoRoute(
            path: '${Routes.dashboardProfile}/:userId',
            builder: (_, s) => PublicProfilePage(userId: s.pathParameters['userId']!),
          ),
          GoRoute(path: Routes.dashboardSettings, builder: (_, __) => const SettingsPage()),
          GoRoute(path: Routes.dashboardInvite, builder: (_, __) => const InvitePage()),
          GoRoute(path: Routes.dashboardBadges, builder: (_, __) => const BadgesPage()),
          GoRoute(path: Routes.dashboardWarnungen, builder: (_, __) => const StubPage(title: 'Warnungen')),
          GoRoute(path: Routes.dashboardWarnungenFood, builder: (_, __) => const StubPage(title: 'Lebensmittelwarnungen')),
          GoRoute(path: Routes.dashboardAdmin, builder: (_, __) => const AdminPage()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('404: ${state.matchedLocation}')),
    ),
  );
});

const _publicRoutes = <String>{
  Routes.root,
  Routes.landing,
  Routes.auth,
  Routes.login,
  Routes.register,
  Routes.download,
  Routes.spenden,
  Routes.unsubscribe,
  Routes.liveEnded,
  Routes.about,
  Routes.agb,
  Routes.datenschutz,
  Routes.impressum,
  Routes.kontakt,
  Routes.haftungsausschluss,
  Routes.nutzungsbedingungen,
  Routes.communityGuidelines,
};

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
