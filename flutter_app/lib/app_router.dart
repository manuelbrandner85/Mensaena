import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/atmosphere/cinema_scaffold.dart';
import 'core/theme/colors.dart';
import 'core/theme/typography.dart';
import 'core/transitions/cinema_page_route.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
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
      _stub('/map', 'Karte'),
      _stub('/posts/new', 'Beitrag erstellen'),
      _stub('/posts/:id', 'Beitrag-Detail'),
      _stub('/chat', 'Chat'),
      _stub('/chat/:conversationId', 'Konversation'),
      _stub('/profile/:id', 'Profil'),
      _stub('/profile/:id/edit', 'Profil bearbeiten'),
      _stub('/notifications', 'Benachrichtigungen'),
      _stub('/search', 'Suche'),
      _stub('/settings', 'Einstellungen'),
      _stub('/board', 'Schwarzes Brett'),

      // 13 Module + Detail-Routen
      _stub('/modules/tiere', 'Tiere'),
      _stub('/modules/wohnen', 'Wohnen'),
      _stub('/modules/mobilitaet', 'Mobilitaet'),
      _stub('/modules/ernte', 'Ernte'),
      _stub('/modules/community', 'Community'),
      _stub('/modules/wissen', 'Wissen / Wiki'),
      _stub('/modules/wissen/:articleId', 'Wiki-Artikel'),
      _stub('/modules/events', 'Veranstaltungen'),
      _stub('/modules/events/:eventId', 'Event-Detail'),
      _stub('/modules/gruppen', 'Gruppen'),
      _stub('/modules/gruppen/:groupId', 'Gruppen-Detail'),
      _stub('/modules/marktplatz', 'Marktplatz'),
      _stub('/modules/marktplatz/:id', 'Listing-Detail'),
      _stub('/modules/challenges', 'Challenges'),
      _stub('/modules/challenges/:id', 'Challenge-Detail'),
      _stub('/modules/badges', 'Badges'),
      _stub('/modules/zeitbank', 'Zeitbank'),
      _stub('/modules/skills', 'Skills'),

      _stub('/admin', 'Admin'),
      _stub('/datenschutz', 'Datenschutz'),
      _stub('/impressum', 'Impressum'),
      _stub('/offline', 'Offline'),
    ];

GoRoute _stub(String path, String title) => GoRoute(
      path: path,
      pageBuilder: (ctx, state) => CinemaPageTransition.build(
        child: _StubScreen(title: title, path: path),
        state: state,
      ),
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
