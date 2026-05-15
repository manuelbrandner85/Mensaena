import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/atmosphere/cinema_scaffold.dart';
import 'core/theme/colors.dart';
import 'core/theme/typography.dart';
import 'core/transitions/cinema_page_route.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/board/board_screen.dart';
import 'features/chat/chat_screen.dart' as chat_view;
import 'features/chat/conversations_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/error/offline_screen.dart';
import 'features/legal/datenschutz_screen.dart';
import 'features/legal/impressum_screen.dart';
import 'features/map/map_screen.dart';
import 'features/modules/all_modules.dart';
import 'features/modules/detail_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/posts/post_create_screen.dart';
import 'features/posts/post_detail_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'providers/auth_provider.dart';

/// Provider fuer den globalen GoRouter. Wird einmalig im ProviderScope
/// instanziiert und kennt den AuthState ueber `authStateChangesProvider`,
/// damit Logout / Login automatisch die richtige Route triggern.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isAuthed = ref.read(isAuthenticatedProvider);
      final loc = state.matchedLocation;
      const public = {'/', '/splash', '/auth', '/datenschutz', '/impressum', '/offline'};
      if (public.contains(loc)) return null;
      if (!isAuthed) return '/auth';
      return null;
    },
    errorPageBuilder: (ctx, state) =>
        CinemaPageTransition.build(child: const _NotFoundScreen(), state: state),
    routes: _buildRoutes(),
  );
});

/// Listenable, das bei jedem AuthState-Event den Router triggert.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    notifyListeners();
    _sub = ref.listen<AsyncValue<AuthState>>(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
    ref.onDispose(() => _sub.close());
  }
  late final ProviderSubscription<AsyncValue<AuthState>> _sub;
}

List<RouteBase> _buildRoutes() => [
      _stub('/', 'Landing'),
      GoRoute(
        path: '/splash',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const SplashScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const AuthScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const DashboardScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/map',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const MapScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/posts/new',
        pageBuilder: (ctx, state) {
          final cat = state.uri.queryParameters['category'];
          return CinemaPageTransition.build(
            child: PostCreateScreen(prefilledCategory: cat),
            state: state,
          );
        },
      ),
      GoRoute(
        path: '/posts/:id',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: PostDetailScreen(postId: state.pathParameters['id']!),
          state: state,
        ),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const ConversationsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: chat_view.ChatScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
          state: state,
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: ProfileScreen(userId: state.pathParameters['id']!),
          state: state,
        ),
      ),
      GoRoute(
        path: '/profile/:id/edit',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: EditProfileScreen(userId: state.pathParameters['id']!),
          state: state,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const NotificationsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const SearchScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const SettingsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/board',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const BoardScreen(),
          state: state,
        ),
      ),

      // 13 Module + Detail-Routen
      _moduleRoute('/modules/tiere', const TiereModule()),
      _moduleRoute('/modules/wohnen', const WohnenModule()),
      _moduleRoute('/modules/mobilitaet', const MobilitaetModule()),
      _moduleRoute('/modules/ernte', const ErnteModule()),
      _moduleRoute('/modules/community', const CommunityModule()),
      _moduleRoute('/modules/wissen', const WissenModule()),
      GoRoute(
        path: '/modules/wissen/:articleId',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: WikiArticleScreen(articleId: state.pathParameters['articleId']!),
          state: state,
        ),
      ),
      _moduleRoute('/modules/events', const EventsModule()),
      GoRoute(
        path: '/modules/events/:eventId',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: EventDetailScreen(eventId: state.pathParameters['eventId']!),
          state: state,
        ),
      ),
      _moduleRoute('/modules/gruppen', const GruppenModule()),
      GoRoute(
        path: '/modules/gruppen/:groupId',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: GroupDetailScreen(groupId: state.pathParameters['groupId']!),
          state: state,
        ),
      ),
      _moduleRoute('/modules/marktplatz', const MarktplatzModule()),
      GoRoute(
        path: '/modules/marktplatz/:id',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: MarketplaceListingScreen(listingId: state.pathParameters['id']!),
          state: state,
        ),
      ),
      _moduleRoute('/modules/challenges', const ChallengesModule()),
      GoRoute(
        path: '/modules/challenges/:id',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: ChallengeDetailScreen(challengeId: state.pathParameters['id']!),
          state: state,
        ),
      ),
      _moduleRoute('/modules/badges', const BadgesModule()),
      _moduleRoute('/modules/zeitbank', const ZeitbankModule()),
      _moduleRoute('/modules/skills', const SkillsModule()),

      GoRoute(
        path: '/admin',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const AdminScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/datenschutz',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const DatenschutzScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/impressum',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const ImpressumScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/offline',
        pageBuilder: (ctx, state) => CinemaPageTransition.build(
          child: const OfflineScreen(),
          state: state,
        ),
      ),
    ];

GoRoute _stub(String path, String title) => GoRoute(
      path: path,
      pageBuilder: (ctx, state) => CinemaPageTransition.build(
        child: _StubScreen(title: title, path: path),
        state: state,
      ),
    );

GoRoute _moduleRoute(String path, Widget screen) => GoRoute(
      path: path,
      pageBuilder: (ctx, state) =>
          CinemaPageTransition.build(child: screen, state: state),
    );

/// Platzhalter-Screen bis Phase 5+ jede Route mit einem echten Screen
/// belegt. Zeigt Modul-Namen und den Pfad — fuer Klick-Tests early.
class _StubScreen extends StatelessWidget {
  final String title;
  final String path;
  const _StubScreen({required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.app,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: MnTypography.display(size: 28)),
              const SizedBox(height: 8),
              Text(path, style: MnTypography.mono(color: MnColors.mute, size: 12)),
              const SizedBox(height: 24),
              Text(
                'Stub-Screen — kommt mit Phase 5+.',
                style: MnTypography.body(color: MnColors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.immersive,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '404',
                style: MnTypography.mono(
                  size: 120,
                  color: MnColors.amber.withValues(alpha: 0.1),
                ),
              ),
              Text(
                'Diese Strasse gibt es nicht.',
                style: MnTypography.display(size: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Aber viele andere in deiner Nachbarschaft.',
                style: MnTypography.body(color: MnColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => GoRouter.of(context).go('/dashboard'),
                child: Text(
                  'Zur Startseite',
                  style: MnTypography.body(color: MnColors.amber),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
