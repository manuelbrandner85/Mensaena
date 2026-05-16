import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../atmosphere/cinema_scaffold.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../../providers/crisis_provider.dart';
import 'cinema_sidebar.dart';

/// 1:1-Web-Spiegelung der Sidebar/Layout-Struktur in Flutter.
///
/// - **Desktop / Tablet (>= 720px)**: persistent CinemaSidebar links.
/// - **Mobile (< 720px)**: Drawer (vom Hamburger-Icon getriggert) + optionale
///   BottomNav als Quick-Access.
///
/// Verwendung in Screens statt CinemaScaffold direkt:
/// ```dart
/// CinemaAppShell(
///   currentRoute: '/dashboard',
///   title: 'DASHBOARD',
///   body: ...,
/// )
/// ```
class CinemaAppShell extends ConsumerStatefulWidget {
  final String currentRoute;
  final String? title;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? appBarActions;
  final bool showBottomNavOnMobile;

  const CinemaAppShell({
    super.key,
    required this.currentRoute,
    required this.body,
    this.title,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBarActions,
    this.showBottomNavOnMobile = true,
  });

  @override
  ConsumerState<CinemaAppShell> createState() => _CinemaAppShellState();
}

class _CinemaAppShellState extends ConsumerState<CinemaAppShell> {
  static const _collapsedKey = 'cinema.sidebar.collapsed.v1';
  bool _collapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _collapsed = p.getBool(_collapsedKey) ?? false);
    });
  }

  Future<void> _toggleCollapse() async {
    setState(() => _collapsed = !_collapsed);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_collapsedKey, _collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final isCrisis = ref.watch(isCrisisActiveProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 720;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: MnColors.voidColor,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: MnColors.voidColor,
              width: 280,
              child: CinemaSidebar(
                currentRoute: widget.currentRoute,
                onItemTap: () => _scaffoldKey.currentState?.closeDrawer(),
              ),
            ),
      body: Row(
        children: [
          if (isDesktop)
            CinemaSidebar(
              currentRoute: widget.currentRoute,
              collapsed: _collapsed,
              onToggleCollapse: _toggleCollapse,
            ),
          Expanded(
            child: CinemaScaffold(
              level: isCrisis
                  ? AtmosphereLevel.crisis
                  : AtmosphereLevel.app,
              isCrisis: isCrisis,
              appBar: widget.title == null
                  ? null
                  : _ShellAppBar(
                      title: widget.title!,
                      onMenuTap: isDesktop
                          ? null
                          : () => _scaffoldKey.currentState?.openDrawer(),
                      actions: widget.appBarActions,
                    ),
              floatingActionButton: widget.floatingActionButton,
              floatingActionButtonLocation: widget.floatingActionButtonLocation,
              body: widget.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// AppBar mit Hamburger-Icon auf Mobile.
class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final List<Widget>? actions;

  const _ShellAppBar({
    required this.title,
    this.onMenuTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: MnColors.voidColor.withValues(alpha: 0.75),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: onMenuTap == null
          ? null
          : IconButton(
              icon: const Icon(LucideIcons.menu, color: MnColors.inkSoft),
              onPressed: onMenuTap,
            ),
      title: Text(title, style: MnTypography.appBarTitle()),
      actions: actions,
    );
  }
}
