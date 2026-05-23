import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/notifications_repository.dart';
import '../navigation/app_drawer.dart';
import '../navigation/notification_bell.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-design
/// Dashboard-Shell: Top-AppBar mit Bell, Drawer mit Module-Navigation,
/// Bottom-NavBar mit 5 Items (Home, Karte, Erstellen, Chat, Mehr).
/// Wird von jedem Dashboard-Screen via DashboardScaffold(body: ...) umschlossen.
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

  static const List<_NavItem> _bottomItems = [
    _NavItem(
      icon: LucideIcons.home,
      label: 'Home',
      route: '/dashboard',
    ),
    _NavItem(
      icon: LucideIcons.map,
      label: 'Karte',
      route: '/dashboard/map',
    ),
    _NavItem(
      icon: LucideIcons.plus,
      label: 'Erstellen',
      route: '/dashboard/create',
    ),
    _NavItem(
      icon: LucideIcons.messageSquare,
      label: 'Chat',
      route: '/dashboard/chat',
    ),
    _NavItem(
      icon: LucideIcons.menu,
      label: 'Mehr',
      route: '_more',
    ),
  ];

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
      bottomNavigationBar: _BottomBar(
        items: _bottomItems,
        currentRoute: currentRoute,
      ),
      floatingActionButton: fab,
      body: body,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.currentRoute,
  });

  final List<_NavItem> items;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deep,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isActive = currentRoute == item.route;
            return Expanded(
              child: InkWell(
                onTap: () {
                  if (item.route == '_more') {
                    Scaffold.of(context).openDrawer();
                  } else {
                    context.go(item.route);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: isActive ? AppColors.amber : AppColors.mute,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.body(
                          size: 10,
                          color: isActive ? AppColors.amber : AppColors.mute,
                          weight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}
