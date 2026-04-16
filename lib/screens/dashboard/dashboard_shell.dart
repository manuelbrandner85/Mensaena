import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/screens/dashboard/app_drawer.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _currentIndex = 0;

  static const _bottomNavPaths = [
    '/dashboard',
    '/dashboard/map',
    '/dashboard/create',
    '/dashboard/messages',
  ];

  void _onTabTapped(int index) {
    if (index == 4) {
      // "Mehr" button -> open drawer
      Scaffold.of(context).openDrawer();
      return;
    }
    setState(() => _currentIndex = index);
    context.go(_bottomNavPaths[index]);
  }

  int _getIndexForPath(String path) {
    for (int i = 0; i < _bottomNavPaths.length; i++) {
      if (path == _bottomNavPaths[i]) return i;
    }
    return -1; // Not a bottom nav path
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final navIndex = _getIndexForPath(location);
    if (navIndex >= 0 && navIndex != _currentIndex) {
      _currentIndex = navIndex;
    }

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref.watch(unreadCountProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex < 4 ? _currentIndex : 0,
        onDestinationSelected: _onTabTapped,
        backgroundColor: AppColors.surface,
        elevation: 8,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Karte',
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            label: 'Erstellen',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(
                '${unreadMessages.valueOrNull ?? 0}',
                style: const TextStyle(fontSize: 10),
              ),
              isLabelVisible: (unreadMessages.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.chat_outlined),
            ),
            selectedIcon: Badge(
              label: Text(
                '${unreadMessages.valueOrNull ?? 0}',
                style: const TextStyle(fontSize: 10),
              ),
              isLabelVisible: (unreadMessages.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.chat),
            ),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(
                '${unreadNotifications.valueOrNull ?? 0}',
                style: const TextStyle(fontSize: 10),
              ),
              isLabelVisible: (unreadNotifications.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.menu),
            ),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}
