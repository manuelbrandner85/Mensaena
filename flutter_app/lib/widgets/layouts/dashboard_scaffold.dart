import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/notifications_repository.dart';
import '../navigation/app_drawer.dart';
import '../navigation/notification_bell.dart';
import '../shared/mensaena_bot_button.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-design
/// Dashboard-Shell — Web-Parity (src/components/navigation/BottomNav.tsx).
/// BottomNav-Reihenfolge: Home / Karte / Erstellen (zentral, primaer) /
/// Nachrichten / Benachrichtigungen.
class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    required this.body,
    required this.title,
    this.currentRoute = '/dashboard',
    this.fab,
    super.key,
  });

  final Widget body;
  final String title;
  final String currentRoute;
  final Widget? fab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        title: Text(title, style: AppTypography.appBarTitle()),
        actions: [
          NotificationBell(unreadCount: unread),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: _BottomNav(currentRoute: currentRoute),
      floatingActionButton: fab,
      body: Stack(
        children: [
          body,
          // MensaenaBot Floating-Button (links unten, oberhalb BottomNav)
          // Nicht ueberlappen mit dem regulaeren FAB (rechts unten).
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(child: const MensaenaBotButton()),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.currentRoute});
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotif = ref.watch(unreadNotificationCountProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deep,
        border: Border(top: BorderSide(color: AppColors.line)),
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
                  icon: LucideIcons.layoutDashboard,
                  label: 'Home',
                  route: '/dashboard',
                  active: currentRoute == '/dashboard',
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.map,
                  label: 'Karte',
                  route: '/dashboard/map',
                  active: currentRoute == '/dashboard/map',
                ),
              ),
              // Zentraler Primary-FAB-Style fuer Erstellen.
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: () => context.go('/dashboard/create'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.amber, AppColors.amberWarm],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGlow,
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.plusCircle,
                      color: AppColors.voidColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.messageCircle,
                  label: 'Chat',
                  route: '/dashboard/messages',
                  active: currentRoute.startsWith('/dashboard/messages') ||
                      currentRoute.startsWith('/dashboard/chat'),
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: LucideIcons.bell,
                  label: 'Bell',
                  route: '/dashboard/notifications',
                  active: currentRoute == '/dashboard/notifications',
                  badge: unreadNotif,
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
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool active;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.amber : AppColors.mute;
    return InkWell(
      onTap: () => context.go(route),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
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
          if (badge > 0)
            Positioned(
              top: 6,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.herzrot,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    size: 9,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
