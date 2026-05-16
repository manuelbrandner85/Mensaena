// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/auth_service.dart';

/// 1:1 Web-Sidebar fuer die Flutter-App.
///
/// Struktur identisch zu `src/components/navigation/navigationConfig.ts`:
///   - 3 Main-Items (Dashboard, Create, Notifications)
///   - 7 Gruppen: KOMMUNIKATION, HELFEN+FINDEN, NOTFALL+SICHERHEIT,
///     GEMEINSCHAFT, TEILEN+RESSOURCEN, WISSEN+SKILLS, MEIN BEREICH
///   - Admin-Gruppe (nur fuer Admins)
///   - Bottom: App-Download, Donate, Logout
///
/// Auf Tablet/Desktop (>=720px) persistent. Auf Mobile als Drawer.
class CinemaSidebar extends ConsumerStatefulWidget {
  final String currentRoute;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onItemTap;

  const CinemaSidebar({
    super.key,
    required this.currentRoute,
    this.collapsed = false,
    this.onToggleCollapse,
    this.onItemTap,
  });

  @override
  ConsumerState<CinemaSidebar> createState() => _CinemaSidebarState();
}

class _CinemaSidebarState extends ConsumerState<CinemaSidebar> {
  final Set<String> _expandedGroups = {
    'kommunikation',
    'mein-bereich',
  };

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isAdmin = profile?['is_admin'] == true;
    final isCollapsed = widget.collapsed;
    final width = isCollapsed ? 68.0 : 260.0;

    return AnimatedContainer(
      duration: MnDimensions.durMed,
      curve: Curves.easeOutCubic,
      width: width,
      color: MnColors.voidColor.withValues(alpha: 0.95),
      child: Column(
        children: [
          _Header(collapsed: isCollapsed, onToggle: widget.onToggleCollapse),
          _SosStrip(collapsed: isCollapsed),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: LucideIcons.layoutDashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  current: widget.currentRoute,
                  collapsed: isCollapsed,
                  onTap: widget.onItemTap,
                ),
                _NavItem(
                  icon: LucideIcons.plusCircle,
                  label: 'Erstellen',
                  route: '/posts/new',
                  current: widget.currentRoute,
                  collapsed: isCollapsed,
                  highlight: true,
                  onTap: widget.onItemTap,
                ),
                _NavItem(
                  icon: LucideIcons.bell,
                  label: 'Benachrichtigungen',
                  route: '/notifications',
                  current: widget.currentRoute,
                  collapsed: isCollapsed,
                  onTap: widget.onItemTap,
                ),

                _Group(
                  id: 'kommunikation',
                  label: 'Kommunikation',
                  icon: LucideIcons.messageCircle,
                  expanded: _expandedGroups.contains('kommunikation'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/messages', 'Nachrichten', LucideIcons.mail),
                    _SubItem('/chat', 'Chat', LucideIcons.messageCircle),
                    _SubItem('/matching', 'Matching', LucideIcons.sparkles),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'helfen-finden',
                  label: 'Helfen & Finden',
                  icon: LucideIcons.heart,
                  expanded: _expandedGroups.contains('helfen-finden'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/map', 'Karte', LucideIcons.mapPin),
                    _SubItem('/posts', 'Beitraege', LucideIcons.fileText),
                    _SubItem('/organizations', 'Organisationen', LucideIcons.building),
                    _SubItem('/interactions', 'Interaktionen', LucideIcons.activity),
                    _SubItem('/modules/tiere', 'Tiere', LucideIcons.dog),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'notfall',
                  label: 'Notfall & Sicherheit',
                  icon: LucideIcons.alertTriangle,
                  accent: MnColors.herzrot,
                  expanded: _expandedGroups.contains('notfall'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/crisis', 'Krise', LucideIcons.alertCircle, accent: MnColors.herzrot),
                    _SubItem('/modules/mental-support', 'Mental Support', LucideIcons.heart),
                    _SubItem('/modules/warnungen', 'Warnungen', LucideIcons.shieldAlert),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'gemeinschaft',
                  label: 'Gemeinschaft',
                  icon: LucideIcons.users,
                  expanded: _expandedGroups.contains('gemeinschaft'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/modules/gruppen', 'Gruppen', LucideIcons.users),
                    _SubItem('/modules/events', 'Events', LucideIcons.calendar),
                    _SubItem('/board', 'Schwarzes Brett', LucideIcons.fileText),
                    _SubItem('/modules/challenges', 'Challenges', LucideIcons.trophy),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'teilen',
                  label: 'Teilen & Ressourcen',
                  icon: LucideIcons.repeat,
                  expanded: _expandedGroups.contains('teilen'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/sharing', 'Sharing', LucideIcons.share2),
                    _SubItem('/modules/zeitbank', 'Zeitbank', LucideIcons.clock),
                    _SubItem('/modules/marktplatz', 'Marktplatz', LucideIcons.shoppingBag),
                    _SubItem('/supply', 'Supply', LucideIcons.package),
                    _SubItem('/modules/ernte', 'Ernte', LucideIcons.leaf),
                    _SubItem('/rescuer', 'Retter', LucideIcons.shieldCheck),
                    _SubItem('/modules/wohnen', 'Wohnen', LucideIcons.home),
                    _SubItem('/modules/mobilitaet', 'Mobilitaet', LucideIcons.car),
                    _SubItem('/jobs', 'Jobs', LucideIcons.briefcase),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'wissen',
                  label: 'Wissen & Skills',
                  icon: LucideIcons.bookOpen,
                  expanded: _expandedGroups.contains('wissen'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/modules/wissen', 'Wiki', LucideIcons.bookOpen),
                    _SubItem('/knowledge', 'Wissen', LucideIcons.lightbulb),
                    _SubItem('/modules/skills', 'Skills', LucideIcons.award),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),
                _Group(
                  id: 'mein-bereich',
                  label: 'Mein Bereich',
                  icon: LucideIcons.userCircle,
                  expanded: _expandedGroups.contains('mein-bereich'),
                  collapsed: isCollapsed,
                  onToggle: _toggleGroup,
                  children: [
                    _SubItem('/profile/me', 'Profil', LucideIcons.user),
                    _SubItem('/invite', 'Einladen', LucideIcons.userPlus),
                    _SubItem('/modules/badges', 'Badges', LucideIcons.award),
                    _SubItem('/calendar', 'Kalender', LucideIcons.calendarDays),
                    _SubItem('/settings', 'Einstellungen', LucideIcons.settings),
                  ],
                  current: widget.currentRoute,
                  onTap: widget.onItemTap,
                ),

                if (isAdmin) ...[
                  const _GroupDivider(label: 'Admin'),
                  _NavItem(
                    icon: LucideIcons.shieldCheck,
                    label: 'Admin-Dashboard',
                    route: '/admin',
                    current: widget.currentRoute,
                    collapsed: isCollapsed,
                    accent: MnColors.amber,
                    onTap: widget.onItemTap,
                  ),
                ],
              ],
            ),
          ),
          _BottomActions(collapsed: isCollapsed, onItemTap: widget.onItemTap),
        ],
      ),
    );
  }

  void _toggleGroup(String id) {
    setState(() {
      if (_expandedGroups.contains(id)) {
        _expandedGroups.remove(id);
      } else {
        _expandedGroups.add(id);
      }
    });
  }
}

class _Header extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onToggle;
  const _Header({required this.collapsed, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MnColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MnColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.zap, color: MnColors.amber, size: 18),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'MENSAENA',
                style: MnTypography.appBarTitle(),
              ),
            ),
          ],
          if (onToggle != null)
            IconButton(
              icon: Icon(
                collapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                size: 18,
                color: MnColors.mute,
              ),
              onPressed: onToggle,
              tooltip: collapsed ? 'Aufklappen' : 'Einklappen',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SosStrip extends ConsumerWidget {
  final bool collapsed;
  const _SosStrip({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        onTap: () => GoRouter.of(context).push('/crisis'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MnColors.herzrot.withValues(alpha: 0.12),
            border: Border.all(color: MnColors.herzrot.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MnColors.herzrot,
                  shape: BoxShape.circle,
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SOS / Krisenhilfe',
                    style: MnTypography.body(
                      color: MnColors.herzrotWarm,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;
  final bool collapsed;
  final bool highlight;
  final Color? accent;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    required this.collapsed,
    this.highlight = false,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = _isActive(current, route);
    final color = accent ?? (active || highlight ? MnColors.amber : MnColors.inkSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          GoRouter.of(context).go(route);
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active ? MnColors.amber.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: MnTypography.body(
                      color: color,
                      size: 14,
                      weight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static bool _isActive(String current, String route) {
    if (route == '/dashboard') return current == '/dashboard' || current == '/';
    return current == route || current.startsWith('$route/');
  }
}

class _Group extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final Color? accent;
  final bool expanded;
  final bool collapsed;
  final void Function(String) onToggle;
  final List<_SubItem> children;
  final String current;
  final VoidCallback? onTap;

  const _Group({
    required this.id,
    required this.label,
    required this.icon,
    this.accent,
    required this.expanded,
    required this.collapsed,
    required this.onToggle,
    required this.children,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onToggle(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: accent ?? MnColors.mute),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: MnTypography.label(
                          color: accent ?? MnColors.mute,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: MnDimensions.durFast,
                      turns: expanded ? 0.5 : 0,
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: MnColors.mute,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expanded && !collapsed)
          ...children.map(
            (s) => _SubItemTile(
              item: s,
              current: current,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _SubItem {
  final String route;
  final String label;
  final IconData icon;
  final Color? accent;
  const _SubItem(this.route, this.label, this.icon, {this.accent});
}

class _SubItemTile extends StatelessWidget {
  final _SubItem item;
  final String current;
  final VoidCallback? onTap;
  const _SubItemTile({required this.item, required this.current, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == item.route || current.startsWith('${item.route}/');
    final color = active
        ? (item.accent ?? MnColors.amber)
        : MnColors.inkSoft.withValues(alpha: 0.85);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 1, 10, 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          GoRouter.of(context).go(item.route);
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? MnColors.amber.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 15, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: MnTypography.body(
                    color: color,
                    size: 13,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  final String label;
  const _GroupDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(label, style: MnTypography.label(color: MnColors.ghost)),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback? onItemTap;
  const _BottomActions({required this.collapsed, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MnColors.line)),
      ),
      child: Column(
        children: [
          _BottomBtn(
            icon: LucideIcons.smartphone,
            label: 'App herunterladen',
            accent: MnColors.amber,
            collapsed: collapsed,
            onTap: () => _launch('https://www.mensaena.de/download'),
          ),
          _BottomBtn(
            icon: LucideIcons.heart,
            label: 'Spenden',
            accent: MnColors.herzrotWarm,
            collapsed: collapsed,
            onTap: () => _launch('https://www.mensaena.de/spenden'),
          ),
          _BottomBtn(
            icon: LucideIcons.logOut,
            label: 'Abmelden',
            accent: MnColors.mute,
            collapsed: collapsed,
            onTap: () async {
              await authService.signOut();
              if (context.mounted) GoRouter.of(context).go('/auth');
              onItemTap?.call();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool collapsed;
  final VoidCallback onTap;

  const _BottomBtn({
    required this.icon,
    required this.label,
    required this.accent,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: MnTypography.body(
                    color: accent,
                    size: 12,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
