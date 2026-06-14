import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:easy_localization/easy_localization.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_layout.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/active_call_provider.dart';
import '../../providers/active_stream_provider.dart';
import '../../providers/pending_actions_provider.dart';
import '../../providers/unread_counts_provider.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/haptics.dart';
import '../../services/recent_pages_service.dart';
import '../../config/module_banners.dart';
import '../shared/module_banner.dart';
import '../shared/my_avatar_top_button.dart';
import '../shared/sos_button.dart';
import '../effects/cinema_overlay.dart';
import '../navigation/language_picker.dart';
import '../dashboard/zeitbank_confirmation_banner.dart';
import '../navigation/app_drawer.dart';
import '../navigation/notification_bell.dart';
import '../shared/active_call_mini_player.dart';
import '../shared/active_stream_mini_player.dart';
import '../assistant/mensaena_assistant_fab.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-design
/// Dashboard-Shell V20 — Performance-Fix mit 100% Optik-Erhalt.
///
/// KERN-ÄNDERUNG: CinemaOverlay ist jetzt ein SEPARATER Layer der
/// EINMAL existiert und UNTER dem Scaffold-Body gerendert wird, statt
/// den Body zu WRAPPEN.
///
/// Vorher (V19):
///   body: CinemaOverlay(child: FcmListener(child: Stack(...)))
///   → CinemaOverlay wird bei jedem Tab-Wechsel disposed + neu gebaut
///   → 4 AnimationControllers sterben + 4 starten = Frame-Spike + Crash
///
/// Nachher (V20):
///   body: Stack(
///     children: [
///       CinemaOverlay(child: SizedBox.expand()), // persistent, nur Atmosphäre
///       FcmListener(child: Stack(...)),           // Content drüber
///     ],
///   )
///   → CinemaOverlay bleibt stabil, Content navigiert darüber
///   → Kein Dispose/Rebuild bei Tab-Wechsel
///
/// Notification-Listener optimiert: Dedizierter leichtgewichtiger Provider
/// statt Stream-Watch. Feuert nur bei neuer ungelesener Notification.
///
/// BottomNav: BackdropFilter sigma von 3 auf 2 reduziert (kaum sichtbar,
/// spart ~25% GPU pro Frame).

// Konsolidierter Provider: liefert die neueste ungelesene Notification
// als Record. Vorher 3 separate Provider die jeweils notificationsStreamProvider
// beobachteten → 3× Rebuild-Cascade pro Stream-Event. Jetzt 1×.
typedef _NewestUnread = ({String? id, String title, String? link});

final _newestUnreadProvider = Provider<_NewestUnread>((ref) {
  final list = ref.watch(notificationsStreamProvider).asData?.value;
  if (list == null || list.isEmpty) {
    return (id: null, title: '', link: null);
  }
  final newest = list.first;
  if (newest.read || newest.readAt != null) {
    return (id: null, title: newest.title, link: newest.link);
  }
  return (id: newest.id, title: newest.title, link: newest.link);
});

// Letzte aufgezeichnete Route. File-static, weil DashboardScaffold ein
// ConsumerWidget ist (kein Instance-State). Reicht: in der App ist immer
// nur EIN Scaffold gleichzeitig sichtbar.
String? _lastRecordedRoute;

// In-Memory-Breadcrumb für schrittweises Zurück. Viele Screens werden via
// context.go() angesteuert — das ERSETZT den go_router-Stack, also kann der
// Zurück-Button nicht „poppen" und sprang bisher hart auf /dashboard. Dieser
// Stack merkt sich den tatsächlichen Navigationspfad, sodass der Zurück-Button
// Schritt für Schritt zur jeweils vorigen Seite zurückführt.
const Set<String> _kTopLevelRoutes = {
  '/dashboard',
  '/dashboard/map',
  '/dashboard/chat',
  '/dashboard/messages',
  '/dashboard/profile',
};
final List<String> _navCrumbs = [];

void _recordCrumb(String route) {
  if (_navCrumbs.isNotEmpty && _navCrumbs.last == route) return;
  // Top-Level-Tab = neuer Wurzel-Kontext: Breadcrumb zurücksetzen.
  if (_kTopLevelRoutes.contains(route)) {
    _navCrumbs
      ..clear()
      ..add(route);
    return;
  }
  final idx = _navCrumbs.indexOf(route);
  if (idx >= 0) {
    // Wir sind zu einer früheren Seite zurück — alles danach abschneiden.
    _navCrumbs.removeRange(idx + 1, _navCrumbs.length);
  } else {
    _navCrumbs.add(route);
  }
}

// Vorige Seite im Breadcrumb (Ziel des Zurück-Buttons, wenn go_router nicht
// poppen kann). null → kein bekannter Vorgänger.
String? _crumbBackTarget() =>
    _navCrumbs.length >= 2 ? _navCrumbs[_navCrumbs.length - 2] : null;

class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    required this.body,
    required this.title,
    this.currentRoute = '/dashboard',
    this.fab,
    this.onRefresh,
    this.headerImage,
    super.key,
  });

  final Widget body;
  final String title;
  final String currentRoute;
  final Widget? fab;
  final Future<void> Function()? onRefresh;

  /// Optionales Higgsfield-Modul-Banner (Asset-Pfad) — fixer Bildstreifen
  /// über dem Body. null = kein Banner.
  final String? headerImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCall = ref.watch(activeCallProvider);
    final activeStream = ref.watch(activeStreamProvider);

    String activeRoute;
    try {
      final matched = GoRouterState.of(context).matchedLocation;
      activeRoute = matched.isNotEmpty ? matched : currentRoute;
    } catch (_) {
      activeRoute = currentRoute;
    }

    // Modul-Banner: explizit gesetzt, sonst aus der aktiven Route (nur
    // exakte Modul-Landings; Detail-Screens bleiben bannerlos).
    final bannerAsset =
        headerImage ?? moduleBanner(activeRoute, prefix: false);

    // Listener auf konsolidierten Record-Provider. Snackbar nur wenn die
    // ungelesene ID sich aendert (nicht bei jedem read-status-toggle).
    ref.listen(_newestUnreadProvider, (prev, next) {
      if (next.id == null || next.id == prev?.id) return;
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      final title = next.title;
      final link = next.link;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.raised,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.bronze,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('NEU',
                style: AppTypography.label(
                    size: 9, color: AppColors.bronze)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 13, color: AppColors.ink),
              ),
            ),
          ],
        ),
        action: link != null && link.isNotEmpty
            ? SnackBarAction(
                label: 'Öffnen',
                textColor: AppColors.bronze,
                onPressed: () => context.go(link),
              )
            : null,
      ));
    });

    final refreshed = onRefresh == null
        ? body
        : RefreshIndicator(
            onRefresh: onRefresh!,
            // Cinema-Branding: Bronze statt Material-Amber, dezenter.
            color: AppColors.bronze,
            backgroundColor: AppColors.surface,
            strokeWidth: 2.6,
            displacement: 44,
            child: body,
          );

    // Back-Button-Logik: Top-Level-Tabs (Home/Karte/Chat/Profil) zeigen
    // den Hamburger fuer den Drawer. ALLE anderen Screens — egal ob via
    // push() oder go() angefahren — zeigen einen Zurueck-Pfeil.
    //
    // canPop() reicht NICHT als Indikator: context.go() ersetzt den Stack,
    // dann ist canPop=false obwohl der User durch klar-erkennbare
    // Detail-Routes navigiert hat (z.B. Settings → Profile-Edit). Daher
    // pruefen wir explizit gegen die Top-Level-Routes.
    //
    // WICHTIG: Drawer wird IMMER gesetzt. Vorher hatte
    // "drawer: canPop ? null : AppDrawer()" einen Bug — wenn der Drawer
    // offen war und canPop flippte, war er gesperrt.
    const topLevelRoutes = {
      '/dashboard',
      '/dashboard/map',
      '/dashboard/chat',
      '/dashboard/messages',
      '/dashboard/profile',
    };
    final isTopLevel = topLevelRoutes.contains(activeRoute);
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? false;
    final showBack = !isTopLevel;

    // Recent-Pages-Tracking: jede Dashboard-Navigation wird in
    // SecureStorage protokolliert, damit der Drawer "Zuletzt"-Section
    // aufpoppen kann.
    //
    // PERF-FIX (App-langsam-Report): Vorher lief addPostFrameCallback
    // bei JEDEM build() — jedes ref.watch-Rebuild (Notification-Stream,
    // unread-Counter, Snackbar-Trigger) hat eine SecureStorage-Read+
    // Write-Plattform-Channel-IO ausgelöst (50–200ms pro Build). Bei
    // schnellen Stream-Echos hat das den Main-Thread blockiert → die
    // App fühlte sich langsam an und konnte unter Last hängen.
    // Jetzt: nur wenn sich die ROUTE seit dem letzten Build geändert
    // hat, wird gespeichert. addPostFrameCallback hält die IO weiter
    // außerhalb des Build-Cycles.
    if (_lastRecordedRoute != activeRoute) {
      _lastRecordedRoute = activeRoute;
      _recordCrumb(activeRoute);
      final route = activeRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RecentPagesService.addRecent(route);
      });
    }
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        // Header IMMER im Cinema-Dark-Look — identisch zur Bottom-Nav, egal
        // welches Theme aktiv ist. Sonst war im Light-Mode der Header hell,
        // während Body (CinemaOverlay) + Bottom-Nav dunkel blieben → Bruch.
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.ink),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Android: helle Icons
          statusBarBrightness: Brightness.dark, // iOS: helle Icons
        ),
        // Gleicher Verlauf + Hairline wie die Bottom-Nav (gespiegelt: Linie
        // unten statt oben), damit oben und unten visuell zusammengehören.
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.elevated, AppColors.surface],
            ),
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
        ),
        leading: showBack
            ? IconButton(
                tooltip: 'common.back'.tr(),
                onPressed: () {
                  // 1) Echter go_router-Stack vorhanden (push) → poppen.
                  // 2) Sonst schrittweise zur vorigen Seite des Breadcrumbs
                  //    (viele Screens kommen via go() → kein pop-barer Stack).
                  // 3) Fallback: Dashboard (statt App-Exit / Home-Sprung).
                  if (canPop) {
                    context.pop();
                  } else {
                    final back = _crumbBackTarget();
                    if (back != null) {
                      // Aktuelle Seite aus dem Breadcrumb nehmen, dann zur
                      // vorigen navigieren (deren build() schneidet sauber zu).
                      if (_navCrumbs.isNotEmpty) _navCrumbs.removeLast();
                      context.go(back);
                    } else {
                      context.go('/dashboard');
                    }
                  }
                },
                icon: const Icon(LucideIcons.arrowLeft, size: 22),
              )
            : null, // Top-Level: automatic-hamburger
        title: Text(title, style: AppTypography.appBarTitle()),
        actions: [
          IconButton(
            tooltip: 'common.search'.tr(),
            onPressed: () => context.push('/dashboard/search'),
            icon: const Icon(LucideIcons.search, size: 20),
          ),
          const SOSButton(),
          const LanguagePicker(),
          const NotificationBell(),
          // P1: Avatar = 1-Tap zum eigenen Profil. Cinema-Bronze-Ring.
          const MyAvatarTopButton(),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),
      // Phase 6: BottomNav nur auf Phones — ab medium uebernimmt die
      // _SideRail links (Tablet/Foldable-Konvention).
      bottomNavigationBar: context.layout.isCompact
          ? _BottomNav(activeRoute: activeRoute)
          : null,
      // Zentraler '+'-FAB entfernt (User-Wunsch 2026-05): jedes Modul hat
      // einen eigenen, zielgerichteten Create-Pfad — ein globaler Picker
      // ist redundant. fab-Parameter wird durchgereicht für Module die
      // ihren eigenen FAB setzen.
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // V20: CinemaOverlay als SEPARATER Background-Layer, nicht als Wrapper.
      // Das SizedBox.expand() ist der "child" — Cinema rendert seine
      // Atmosphäre dahinter. Content liegt als zweites Stack-Kind DRÜBER.
      // → CinemaOverlay wird NICHT disposed bei Tab-Wechsel.
      // → AnimationControllers laufen stabil weiter.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Cinema-Atmosphäre (persistent, nur Deko)
          const RepaintBoundary(
            child: CinemaOverlay(child: SizedBox.expand()),
          ),
          // Layer 2: Actual Content
          // Listener (Fcm/IncomingCall/CriticalCrisis) sind als SINGLETONS
          // in app.dart MaterialApp.router.builder gemountet — NICHT hier.
          // Jeder Screen instanziiert seinen eigenen DashboardScaffold, d.h.
          // ein Wrap hier würde bei jeder Navigation Realtime-/FCM-Subs
          // disposen + neu öffnen → Socket-Churn → Crash nach 2. Tap.
          Row(children: [
            if (context.layout.isAtLeastMedium)
              _SideRail(activeRoute: activeRoute),
            Expanded(
                child: Stack(
            children: [
              Column(
                children: [
                  const ZeitbankConfirmationBanner(),
                  // Auto-Banner: explizit gesetztes headerImage, sonst aus
                  // der aktiven Route (nur exakte Modul-Landing-Routen —
                  // Detail-Screens mit eigenem Hero bleiben bannerlos).
                  // Das Banner liegt als kollabierender Header im
                  // NestedScrollView → es SCROLLT mit dem Content nach oben
                  // weg und gibt vollen Platz frei, statt fix zu bleiben.
                  Expanded(
                    child: bannerAsset == null
                        ? refreshed
                        : NestedScrollView(
                            floatHeaderSlivers: true,
                            headerSliverBuilder: (_, __) => [
                              SliverToBoxAdapter(
                                  child: ModuleBanner(asset: bannerAsset)),
                            ],
                            body: refreshed,
                          ),
                  ),
                ],
              ),
              // "Mensa"-Assistent: schwebt über der BottomNav, verschiebbar.
              // Ausgeblendet im Chat/Krisen-Kontext.
              if (!activeRoute.contains('/chat') &&
                  !activeRoute.contains('/crisis'))
                _DraggableAssistantFab(screenLabel: title),
              if (activeCall != null &&
                  !activeRoute.startsWith('/dashboard/call/'))
                ActiveCallMiniPlayer(info: activeCall),
              if (activeStream != null &&
                  !activeRoute.startsWith('/dashboard/live/'))
                ActiveStreamMiniPlayer(info: activeStream),
            ],
          )),
          ]),
        ],
      ),
    );
  }
}

// _PlusFab entfernt (User-Wunsch 2026-05): zentraler '+'-Create-Picker
// raus — jedes Modul hat seinen eigenen zielgerichteten Create-Pfad.

/// Phase 6: Seitliche Navigation ab medium (Tablets/Foldables) — gleiche
/// 4 Ziele + Badges wie die _BottomNav, als schmale Spalte links.
class _SideRail extends ConsumerWidget {
  const _SideRail({required this.activeRoute});
  final String activeRoute;

  bool _matches(String route, List<String> prefixes) {
    for (final p in prefixes) {
      if (activeRoute == p) return true;
      if (activeRoute.startsWith('$p/')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingActions =
        ref.watch(pendingActionsCountProvider).value ?? 0;
    final unreadDm = ref.watch(unreadDmCountProvider).value ?? 0;
    return Container(
      width: 84,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.elevated, AppColors.surface],
        ),
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: _BottomItem(
                icon: LucideIcons.home,
                label: 'nav.home'.tr(),
                route: '/dashboard',
                active: activeRoute == '/dashboard',
              ),
            ),
            SizedBox(
              height: 64,
              child: _BottomItem(
                icon: LucideIcons.map,
                label: 'nav.map'.tr(),
                route: '/dashboard/map',
                active: _matches(activeRoute, ['/dashboard/map']),
              ),
            ),
            SizedBox(
              height: 64,
              child: _BottomItem(
                icon: LucideIcons.messageSquare,
                label: 'nav.chat'.tr(),
                route: '/dashboard/messages',
                active: _matches(activeRoute, [
                  '/dashboard/messages',
                  '/dashboard/chat',
                ]),
                badgeCount: unreadDm,
              ),
            ),
            SizedBox(
              height: 64,
              child: _BottomItem(
                icon: LucideIcons.user,
                label: 'nav.profile'.tr(),
                route: '/dashboard/profile',
                active: _matches(activeRoute, ['/dashboard/profile']),
                badgeCount: pendingActions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// V20: BottomNav — BackdropFilter BLEIBT aber sigma von 3 auf 2 reduziert.
/// Visuell kaum Unterschied (3→2), spart ~25% GPU-Last pro Frame.
class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.activeRoute});
  final String activeRoute;

  bool _matches(String route, List<String> prefixes) {
    for (final p in prefixes) {
      if (activeRoute == p) return true;
      if (activeRoute.startsWith('$p/')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // H2: aggregierter Pending-Counter — eingehende Hilfe-Anfragen +
    // Matches + Freundschaftsanfragen. Ersetzt den isolierten
    // pendingMatches-Badge.
    final pendingActions =
        ref.watch(pendingActionsCountProvider).value ?? 0;
    final unreadDm = ref.watch(unreadDmCountProvider).value ?? 0;
    // Crash-Fix (User-Report 2026-05): klassische angedockte Bottom-Nav
    // statt schwebender Glass-Pill. Die Floating-Pill mit BackdropFilter +
    // ClipRRect + Container im bottomNavigationBar-Slot war als Crash-
    // Verdächtiger bei Nav-Tap markiert. Stabile Material-Standard-
    // Struktur, Cinema-Look bleibt via Tokens.
    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            // Dezenter Vertikal-Verlauf hebt die Bar optisch von der Fläche
            // ab — bleibt GPU-leicht (kein BackdropFilter, Crash-Historie!).
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.elevated, AppColors.surface],
            ),
            border: const Border(top: BorderSide(color: AppColors.line)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.home,
                  label: 'nav.home'.tr(),
                  route: '/dashboard',
                  active: activeRoute == '/dashboard',
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.map,
                  label: 'nav.map'.tr(),
                  route: '/dashboard/map',
                  active: _matches(activeRoute, ['/dashboard/map']),
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.messageSquare,
                  label: 'nav.chat'.tr(),
                  route: '/dashboard/messages',
                  active: _matches(activeRoute, [
                    '/dashboard/messages',
                    '/dashboard/chat',
                  ]),
                  badgeCount: unreadDm,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.user,
                  label: 'nav.profile'.tr(),
                  route: '/dashboard/profile',
                  active: _matches(activeRoute, ['/dashboard/profile']),
                  badgeCount: pendingActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.active,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool active;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    // Design (Cinema-Hyperreal): aktiv = Bronze-Glyph mit Glow + Papier-Label,
    // inaktiv = gedämpftes Papier (paper-dim).
    final glyphColor = active ? AppColors.bronze : AppColors.inkSoft;
    final labelColor = active ? AppColors.ink : AppColors.mute;
    return InkWell(
      onTap: () {
        Haptics.select();
        context.go(route);
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: active
              ? BoxDecoration(
                  // Verlaufs-Pille statt Flachton + weicher Bronze-Glow:
                  // hebt die aktive Sektion filmischer hervor.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bronze.withValues(alpha: 0.22),
                      AppColors.bronze.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.40),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bronze.withValues(alpha: 0.22),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Aktiver Glyph mit Bronze-Drop-Shadow-Glow (Design).
                  active
                      ? Icon(
                          icon,
                          size: 20,
                          color: glyphColor,
                          shadows: [
                            Shadow(
                              color: AppColors.bronze.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        )
                      : Icon(icon, size: 20, color: glyphColor),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: AppTypography.mono(
                              size: 8,
                              color: AppColors.voidColor,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              // Design: Nav-Label als Mono-Uppercase mit weitem Tracking.
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  size: 8.5,
                  color: labelColor,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Draggable FAB-Wrapper ─────────────────────────────────────────────────────
// Merkt sich die Position des "Mensa"-Assistenten (In-Memory — reset on
// App-Restart). Standardposition: rechts unten, knapp über der BottomNav.
// Ziehen verschiebt den Button; Tap öffnet weiterhin das Chat-Sheet.
class _DraggableAssistantFab extends StatefulWidget {
  const _DraggableAssistantFab({required this.screenLabel});
  final String screenLabel;

  @override
  State<_DraggableAssistantFab> createState() => _DraggableAssistantFabState();
}

class _DraggableAssistantFabState extends State<_DraggableAssistantFab> {
  // right / bottom Abstände in Logical Pixels.
  double _right = 16;
  double _bottom = 88;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      right: _right,
      bottom: _bottom,
      child: GestureDetector(
        // onPanUpdate: Button verschieben.
        onPanUpdate: (d) {
          setState(() {
            _right = (_right - d.delta.dx).clamp(8.0, size.width - 66.0);
            _bottom = (_bottom - d.delta.dy).clamp(88.0, size.height - 160.0);
          });
        },
        child: MensaenaAssistantFab(screenLabel: widget.screenLabel),
      ),
    );
  }
}
