import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase.dart';
import '../features/auth/auth_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/landing/landing_page.dart';
import '../features/legal/legal_pages.dart';
import '../features/live_ended/live_ended_page.dart';
import '../features/messages/conversation_page.dart';
import '../features/messages/messages_page.dart';
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
      GoRoute(path: Routes.auth, builder: (_, s) => AuthPage(mode: s.uri.queryParameters['mode'] ?? 'login')),
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
          GoRoute(path: Routes.dashboardCreate, builder: (_, __) => const StubPage(title: 'Erstellen')),
          GoRoute(path: Routes.dashboardNotifications, builder: (_, __) => const StubPage(title: 'Benachrichtigungen')),
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
          GoRoute(path: Routes.dashboardChat, builder: (_, __) => const StubPage(title: 'Community Chat')),
          GoRoute(path: Routes.dashboardMatching, builder: (_, __) => const StubPage(title: 'Matching')),
          GoRoute(path: Routes.dashboardMap, builder: (_, __) => const StubPage(title: 'Karte')),
          GoRoute(path: Routes.dashboardPosts, builder: (_, __) => const StubPage(title: 'Hilfe-Posts')),
          GoRoute(path: '${Routes.dashboardPosts}/:id', builder: (_, s) => StubPage(title: 'Post ${s.pathParameters['id']}')),
          GoRoute(path: Routes.dashboardOrganizations, builder: (_, __) => const StubPage(title: 'Organisationen')),
          GoRoute(path: '${Routes.dashboardOrganizations}/:orgId', builder: (_, s) => StubPage(title: 'Org ${s.pathParameters['orgId']}')),
          GoRoute(path: Routes.dashboardOrganizationsSuggest, builder: (_, __) => const StubPage(title: 'Organisation vorschlagen')),
          GoRoute(path: Routes.dashboardInteractions, builder: (_, __) => const StubPage(title: 'Interaktionen')),
          GoRoute(path: '${Routes.dashboardInteractions}/:interactionId', builder: (_, s) => StubPage(title: 'Interaktion ${s.pathParameters['interactionId']}')),
          GoRoute(path: Routes.dashboardAnimals, builder: (_, __) => const StubPage(title: 'Tiere')),
          GoRoute(path: Routes.dashboardAnimalsCreate, builder: (_, __) => const StubPage(title: 'Tier melden')),
          GoRoute(path: Routes.dashboardCrisis, builder: (_, __) => const StubPage(title: 'Krisenberichte')),
          GoRoute(path: '${Routes.dashboardCrisis}/:crisisId', builder: (_, s) => StubPage(title: 'Krise ${s.pathParameters['crisisId']}')),
          GoRoute(path: Routes.dashboardCrisisCreate, builder: (_, __) => const StubPage(title: 'Krise melden')),
          GoRoute(path: Routes.dashboardCrisisResources, builder: (_, __) => const StubPage(title: 'Krisen-Ressourcen')),
          GoRoute(path: Routes.dashboardMentalSupport, builder: (_, __) => const StubPage(title: 'Psychische Unterstützung')),
          GoRoute(path: Routes.dashboardMentalSupportCreate, builder: (_, __) => const StubPage(title: 'Mental-Support erstellen')),
          GoRoute(path: Routes.dashboardGroups, builder: (_, __) => const StubPage(title: 'Gruppen')),
          GoRoute(path: '${Routes.dashboardGroups}/:groupId', builder: (_, s) => StubPage(title: 'Gruppe ${s.pathParameters['groupId']}')),
          GoRoute(path: Routes.dashboardGroupsCreate, builder: (_, __) => const StubPage(title: 'Gruppe erstellen')),
          GoRoute(path: Routes.dashboardEvents, builder: (_, __) => const StubPage(title: 'Veranstaltungen')),
          GoRoute(path: '${Routes.dashboardEvents}/:id', builder: (_, s) => StubPage(title: 'Event ${s.pathParameters['id']}')),
          GoRoute(path: Routes.dashboardEventsCreate, builder: (_, __) => const StubPage(title: 'Event erstellen')),
          GoRoute(path: Routes.dashboardBoard, builder: (_, __) => const StubPage(title: 'Pinnwand')),
          GoRoute(path: Routes.dashboardChallenges, builder: (_, __) => const StubPage(title: 'Challenges')),
          GoRoute(path: Routes.dashboardChallengesCreate, builder: (_, __) => const StubPage(title: 'Challenge erstellen')),
          GoRoute(path: Routes.dashboardSharing, builder: (_, __) => const StubPage(title: 'Teilen')),
          GoRoute(path: Routes.dashboardSharingCreate, builder: (_, __) => const StubPage(title: 'Teilen erstellen')),
          GoRoute(path: Routes.dashboardTimebank, builder: (_, __) => const StubPage(title: 'Zeitbank')),
          GoRoute(path: Routes.dashboardMarketplace, builder: (_, __) => const StubPage(title: 'Marktplatz')),
          GoRoute(path: Routes.dashboardMarketplaceCreate, builder: (_, __) => const StubPage(title: 'Marktplatz-Inserat')),
          GoRoute(path: Routes.dashboardSupply, builder: (_, __) => const StubPage(title: 'Vorrat')),
          GoRoute(path: '${Routes.dashboardSupply}/farm/:slug', builder: (_, s) => StubPage(title: 'Farm ${s.pathParameters['slug']}')),
          GoRoute(path: Routes.dashboardSupplyFarmAdd, builder: (_, __) => const StubPage(title: 'Farm hinzufügen')),
          GoRoute(path: Routes.dashboardHarvest, builder: (_, __) => const StubPage(title: 'Ernte')),
          GoRoute(path: Routes.dashboardHarvestCreate, builder: (_, __) => const StubPage(title: 'Ernte erstellen')),
          GoRoute(path: Routes.dashboardRescuer, builder: (_, __) => const StubPage(title: 'Lebensretter')),
          GoRoute(path: Routes.dashboardRescuerCreate, builder: (_, __) => const StubPage(title: 'Rescuer erstellen')),
          GoRoute(path: Routes.dashboardHousing, builder: (_, __) => const StubPage(title: 'Wohnen')),
          GoRoute(path: Routes.dashboardHousingCreate, builder: (_, __) => const StubPage(title: 'Wohnungs-Inserat')),
          GoRoute(path: Routes.dashboardMobility, builder: (_, __) => const StubPage(title: 'Mobilität')),
          GoRoute(path: Routes.dashboardMobilityCreate, builder: (_, __) => const StubPage(title: 'Fahrt anbieten')),
          GoRoute(path: Routes.dashboardJobs, builder: (_, __) => const StubPage(title: 'Jobs')),
          GoRoute(path: Routes.dashboardWiki, builder: (_, __) => const StubPage(title: 'Wiki')),
          GoRoute(path: Routes.dashboardWikiCreate, builder: (_, __) => const StubPage(title: 'Wiki-Eintrag')),
          GoRoute(path: Routes.dashboardKnowledge, builder: (_, __) => const StubPage(title: 'Bildung')),
          GoRoute(path: Routes.dashboardKnowledgeCreate, builder: (_, __) => const StubPage(title: 'Bildung erstellen')),
          GoRoute(path: Routes.dashboardSkills, builder: (_, __) => const StubPage(title: 'Skills')),
          GoRoute(path: Routes.dashboardSkillsCreate, builder: (_, __) => const StubPage(title: 'Skill anbieten')),
          GoRoute(path: Routes.dashboardCalendar, builder: (_, __) => const StubPage(title: 'Kalender')),
          GoRoute(path: Routes.dashboardCommunity, builder: (_, __) => const StubPage(title: 'Community')),
          GoRoute(path: Routes.dashboardCommunityCreate, builder: (_, __) => const StubPage(title: 'Community erstellen')),
          GoRoute(path: Routes.dashboardProfile, builder: (_, __) => const StubPage(title: 'Mein Profil')),
          GoRoute(path: '${Routes.dashboardProfile}/:userId', builder: (_, s) => StubPage(title: 'Profil ${s.pathParameters['userId']}')),
          GoRoute(path: Routes.dashboardSettings, builder: (_, __) => const StubPage(title: 'Einstellungen')),
          GoRoute(path: Routes.dashboardInvite, builder: (_, __) => const StubPage(title: 'Nachbarn einladen')),
          GoRoute(path: Routes.dashboardBadges, builder: (_, __) => const StubPage(title: 'Abzeichen')),
          GoRoute(path: Routes.dashboardWarnungen, builder: (_, __) => const StubPage(title: 'Warnungen')),
          GoRoute(path: Routes.dashboardWarnungenFood, builder: (_, __) => const StubPage(title: 'Lebensmittelwarnungen')),
          GoRoute(path: Routes.dashboardAdmin, builder: (_, __) => const StubPage(title: 'Admin')),
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
