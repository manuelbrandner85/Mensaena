import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/badges.dart';
import 'badge_counts.dart';
import 'nav_config.dart';
import 'sidebar.dart';
import 'topbar.dart';

/// Dashboard-Hülle: Topbar + (Mobile: BottomNav, Desktop/Tablet: Sidebar links).
/// Pendant zu src/components/navigation/AppShell.tsx.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _desktopBreakpoint = 1024.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= _desktopBreakpoint;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            const SizedBox(width: 280, child: Sidebar()),
            Expanded(
              child: Column(
                children: [
                  const Topbar(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const Drawer(child: Sidebar()),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Topbar(),
      ),
      body: child,
      bottomNavigationBar: _AppBottomNav(),
    );
  }
}

class _AppBottomNav extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final counts = ref.watch(badgeCountsProvider).asData?.value ?? const BadgeCounts();

    final selectedIndex = bottomNavItems
        .indexWhere((item) => location.startsWith(item.path));

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (i) => context.go(bottomNavItems[i].path),
      destinations: [
        for (final item in bottomNavItems)
          NavigationDestination(
            icon: _BottomNavIcon(item: item, count: counts.forKey(item.badgeKey)),
            selectedIcon: _BottomNavIcon(item: item, count: counts.forKey(item.badgeKey), selected: true),
            label: item.label,
          ),
      ],
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  const _BottomNavIcon({required this.item, this.count = 0, this.selected = false});
  final NavItem item;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final highlight = item.variant == NavVariant.highlight;
    final iconWidget = Container(
      decoration: highlight
          ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary400, AppColors.primary600],
              ),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      padding: highlight ? const EdgeInsets.all(6) : EdgeInsets.zero,
      child: Icon(
        item.icon,
        color: highlight
            ? Colors.white
            : (selected ? AppColors.primary700 : AppColors.stone500),
      ),
    );

    if (count == 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(top: -4, right: -8, child: CountBadge(count: count)),
      ],
    );
  }
}
