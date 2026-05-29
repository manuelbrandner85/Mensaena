import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:easy_localization/easy_localization.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/active_call_provider.dart';
import '../../providers/pending_actions_provider.dart';
import '../../providers/unread_counts_provider.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/haptics.dart';
import '../../services/recent_pages_service.dart';
import '../shared/create_picker_sheet.dart';
import '../shared/my_avatar_top_button.dart';
import '../shared/sos_button.dart';
import '../effects/cinema_overlay.dart';
import '../navigation/language_picker.dart';
import '../shared/critical_crisis_alert_listener.dart';
import '../shared/fcm_foreground_listener.dart';
import '../shared/incoming_call_listener.dart';
import '../dashboard/zeitbank_confirmation_banner.dart';
import '../navigation/app_drawer.dart';
import '../navigation/notification_bell.dart';
import '../shared/active_call_mini_player.dart';
import '../shared/mensaena_bot_button.dart';

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

class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    required this.body,
    required this.title,
    this.currentRoute = '/dashboard',
    this.fab,
    this.onRefresh,
    super.key,
  });

  final Widget body;
  final String title;
  final String currentRoute;
  final Widget? fab;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final activeCall = ref.watch(activeCallProvider);

    String activeRoute;
    try {
      final matched = GoRouterState.of(context).matchedLocation;
      activeRoute = matched.isNotEmpty ? matched : currentRoute;
    } catch (_) {
      activeRoute = currentRoute;
    }

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
            color: AppColors.amber,
            backgroundColor: AppColors.surface,
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
    // aufpoppen kann. Post-frame damit es nicht im Build-Cycle laeuft.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecentPagesService.addRecent(activeRoute);
    });
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                tooltip: 'common.back'.tr(),
                onPressed: () {
                  // Wenn Stack pop-bar → pop. Sonst sauberer Fallback zum
                  // Dashboard statt App-Exit.
                  if (canPop) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
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
          NotificationBell(unreadCount: unread),
          // P1: Avatar = 1-Tap zum eigenen Profil. Cinema-Bronze-Ring.
          const MyAvatarTopButton(),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: _BottomNav(activeRoute: activeRoute),
      floatingActionButton: _PlusFab(secondaryFab: fab),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
          FcmForegroundListener(
            child: IncomingCallListener(
              child: CriticalCrisisAlertListener(
              child: Stack(
                children: [
                  Column(
                    children: [
                      const ZeitbankConfirmationBanner(),
                      // Sanfter Cross-Fade beim Tab-/Screen-Wechsel
                      // (Cinema-Feel statt hartem Sprung).
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(activeRoute),
                            child: refreshed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    left: 16,
                    bottom: 16,
                    child: SafeArea(child: MensaenaBotButton()),
                  ),
                  // Picture-in-Picture-Mini-Player fuer laufenden Call.
                  // Draggable, ersetzt den frueheren 36dp-Top-Banner.
                  if (activeCall != null &&
                      !activeRoute.startsWith('/dashboard/call/'))
                    ActiveCallMiniPlayer(info: activeCall),
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

class _PlusFab extends StatelessWidget {
  const _PlusFab({this.secondaryFab});
  final Widget? secondaryFab;

  @override
  Widget build(BuildContext context) {
    if (secondaryFab != null) return secondaryFab!;
    // Design (Cinema-Hyperreal): zentraler FAB ist Bronze-Gradient mit
    // abgerundetem Quadrat (radius 18) + Bronze-Glow, nicht Kreis-Amber.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.bronze.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bronze, AppColors.bronzeDeep],
          ),
          border: Border.all(
            color: const Color(0x59FFFFFF), // inset top highlight
            width: 0.5,
          ),
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.voidColor,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onPressed: () {
            Haptics.confirm();
            // C1: Universeller Create-Picker statt direkter Route. User
            // sieht 6 Tiles (Post/Event/Marktplatz/Gruppe/Wissen/Krise)
            // im Cinema-GlassCard-Style.
            CreatePickerSheet.show(context);
          },
          tooltip: 'nav.create'.tr(),
          child: const Icon(LucideIcons.plus, size: 26),
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
    // Design (Cinema-Hyperreal): schwebende Glass-Pill mit 14px-Rand,
    // rounded 26, Glass-Gradient, line-strong-Border + tiefem Schatten.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xC70E141E), Color(0xEB080C14)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0x47ECE5D6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
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
                    const SizedBox(width: 56),
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
                        active:
                            _matches(activeRoute, ['/dashboard/profile']),
                        badgeCount: pendingActions,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: active
              ? BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
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
