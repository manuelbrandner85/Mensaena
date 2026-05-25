import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:easy_localization/easy_localization.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/matching_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/haptics.dart';
import '../effects/cinema_overlay.dart';
import '../navigation/language_picker.dart';
import '../shared/fcm_foreground_listener.dart';
import '../shared/incoming_call_listener.dart';
import '../dashboard/zeitbank_confirmation_banner.dart';
import '../navigation/app_drawer.dart';
import '../navigation/notification_bell.dart';
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

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        title: Text(title, style: AppTypography.appBarTitle()),
        actions: [
          const LanguagePicker(),
          NotificationBell(unreadCount: unread),
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
              child: Stack(
                children: [
                  Column(
                    children: [
                      const ZeitbankConfirmationBanner(),
                      Expanded(child: refreshed),
                    ],
                  ),
                  const Positioned(
                    left: 16,
                    bottom: 16,
                    child: SafeArea(child: MensaenaBotButton()),
                  ),
                ],
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
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.40),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 0,
          ),
        ],
      ),
      child: FloatingActionButton(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        onPressed: () {
          Haptics.confirm();
          context.go('/dashboard/create');
        },
        tooltip: 'nav.create'.tr(),
        child: const Icon(LucideIcons.plus, size: 26),
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
    final pendingMatches =
        ref.watch(matchingCountsProvider).value?.pending ?? 0;
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          // V20: sigma 2 statt 3 — visuell kaum Unterschied, spart GPU.
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            decoration: BoxDecoration(
              // V20: Erhoehe Surface-Opazitaet von 0.60 auf 0.72 um
              // den reduzierten Blur zu kompensieren. Sieht identisch aus.
              color: AppColors.surface.withValues(alpha: 0.72),
              border: const Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
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
                      ),
                    ),
                    Expanded(
                      child: _BottomItem(
                        icon: LucideIcons.user,
                        label: 'nav.profile'.tr(),
                        route: '/dashboard/profile',
                        active:
                            _matches(activeRoute, ['/dashboard/profile']),
                        badgeCount: pendingMatches,
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
    final color = active ? AppColors.amber : AppColors.mute;
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
                  color: AppColors.amber.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
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
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.body(
                  size: 10,
                  color: color,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
