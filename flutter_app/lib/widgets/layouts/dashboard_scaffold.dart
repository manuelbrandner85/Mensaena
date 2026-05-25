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
/// Dashboard-Shell — 4-Tab BottomNav (Home/Karte/Chat/Profil) + zentraler
/// schwebender FAB (Plus → /dashboard/create). Notification-Bell mit Badge
/// rechts in der AppBar. MensaenaBotButton bleibt als floating Overlay
/// rechts/links unten.
///
/// V19: Optionaler `onRefresh`-Callback wrappt den body in einen
/// RefreshIndicator (amber). Screens mit eigenem inline-RefreshIndicator
/// uebergeben den Callback NICHT (kein doppeltes Wrapping).
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

  /// Optional secondary FAB — wird zusaetzlich zum zentralen Plus-FAB im
  /// BottomNav angezeigt (rechts unten). Selten genutzt; meist null.
  final Widget? fab;

  /// Wenn gesetzt, wird `body` in einen RefreshIndicator gewrappt.
  /// Pull-Down loest den Callback aus. Color: AppColors.amber.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    // Aktiv-Tab via GoRouter ableiten (matchedLocation), Fallback auf
    // currentRoute-Parameter (Backwards-Compat).
    // Bug-Fix: GoRouterState.of(context) wirft wenn der Context AUSSERHALB
    // des GoRouter-Subtrees liegt (z.B. waehrend Page-Transitions oder in
    // Bottom-Sheets). Try/catch verhindert Crash + faellt auf
    // currentRoute-Parameter zurueck.
    String activeRoute;
    try {
      final matched = GoRouterState.of(context).matchedLocation;
      activeRoute = matched.isNotEmpty ? matched : currentRoute;
    } catch (_) {
      activeRoute = currentRoute;
    }

    // Realtime-Toast: zeige bei jeder neuen Notification eine Snackbar.
    ref.listen(notificationsStreamProvider, (prev, next) {
      final list = next.value;
      if (list == null || list.isEmpty) return;
      final newest = list.first;
      final wasNewer = prev?.value?.firstOrNull?.id != newest.id;
      if (!wasNewer) return;
      if (newest.read || newest.readAt != null) return;
      // Haptic + Sound (System-Notification)
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      // Toast zeigen
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
                newest.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 13, color: AppColors.ink),
              ),
            ),
          ],
        ),
        action: newest.link != null && newest.link!.isNotEmpty
            ? SnackBarAction(
                label: 'Öffnen',
                textColor: AppColors.bronze,
                onPressed: () => context.go(newest.link!),
              )
            : null,
      ));
    });

    // Body ggf. mit RefreshIndicator wrappen (V19).
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
      body: CinemaOverlay(
        child: FcmForegroundListener(
          child: IncomingCallListener(
            child: Stack(
              children: [
                Column(
                  children: [
                    const ZeitbankConfirmationBanner(),
                    Expanded(child: refreshed),
                  ],
                ),
                // MensaenaBot Floating-Button (links unten, oberhalb BottomNav)
                // Nicht ueberlappen mit dem zentralen Plus-FAB.
                const Positioned(
                  left: 16,
                  bottom: 16,
                  child: SafeArea(child: MensaenaBotButton()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zentraler schwebender Plus-FAB — schwebt 24dp oberhalb der BottomNav.
/// Cinema-Glow: amber.withOpacity(0.4) Bloom, blur 16, spread -2.
/// Falls ein `secondaryFab` uebergeben wurde (vom Caller), wird er rechts
/// unten zusaetzlich angezeigt — wir nutzen dafuer einen Stack.
class _PlusFab extends StatelessWidget {
  const _PlusFab({this.secondaryFab});
  final Widget? secondaryFab;

  @override
  Widget build(BuildContext context) {
    // Wenn secondaryFab vorhanden, zeigen wir nur den secondary an, weil
    // FloatingActionButtonLocation nur einen FAB platzieren kann.
    // (Edge-Case: posts_list_screen etc. uebergeben ihren eigenen
    // "Post"-FAB. In dem Fall behalten wir das alte Verhalten.)
    if (secondaryFab != null) return secondaryFab!;
    return Container(
      // Bloom-Glow: amber.withOpacity(0.4), blur 16, spread -2.
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
    // Pending-Match-Count fuer Profile-Tab-Badge (klein, amber).
    final pendingMatches =
        ref.watch(matchingCountsProvider).value?.pending ?? 0;
    // Glass-Effekt: BackdropFilter blur(8) + surface.withOpacity(0.6).
    return ClipRect(
      child: BackdropFilter(
        // sigma 3 statt 8 — auf mittleren Geraeten reicht das fuers Glass-
        // Gefuehl + halbiert die GPU-Last beim Scroll/Transition.
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.60),
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
                  // Spacer fuer zentralen FAB (centerDocked).
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
                      active: _matches(activeRoute, ['/dashboard/profile']),
                      badgeCount: pendingMatches,
                    ),
                  ),
                ],
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

  /// Optionales Mini-Badge oben rechts auf dem Icon (z.B. Pending-Matches).
  /// 0 = kein Badge. > 99 zeigt "99+".
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.amber : AppColors.mute;
    // Aktiver Tab: subtle GlassCard-aehnlicher Hintergrund (blur via Container
    // mit amber-tint). Echtes BackdropFilter koennte teuer sein hier — wir
    // simulieren den Glass-Effekt mit einem amber-getoenten Pill.
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
