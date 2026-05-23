import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';

/// SKILL: flutter-setup-declarative-routing + mensaena-design
/// Module-Navigation per Drawer. Spiegelt die Web-Sidebar-Struktur:
/// 6 Hauptgruppen + Admin (wenn role).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const List<_NavGroup> _groups = [
    _NavGroup(
      label: 'Nachbarschaft',
      items: [
        _NavLink(
            icon: LucideIcons.home, label: 'Übersicht', route: '/dashboard'),
        _NavLink(
            icon: LucideIcons.map, label: 'Karte', route: '/dashboard/map'),
        _NavLink(
            icon: LucideIcons.fileText,
            label: 'Beiträge',
            route: '/dashboard/posts'),
        _NavLink(
            icon: LucideIcons.users,
            label: 'Community',
            route: '/dashboard/community'),
        _NavLink(
            icon: LucideIcons.bell,
            label: 'Benachrichtigungen',
            route: '/dashboard/notifications'),
      ],
    ),
    _NavGroup(
      label: 'Hilfe & Krise',
      items: [
        _NavLink(
            icon: LucideIcons.alertTriangle,
            label: 'Krisenmodus',
            route: '/dashboard/crisis'),
        _NavLink(
            icon: LucideIcons.shieldAlert,
            label: 'NINA-Warnungen',
            route: '/dashboard/warnungen'),
        _NavLink(
            icon: LucideIcons.helpingHand,
            label: 'Interaktionen',
            route: '/dashboard/interactions'),
        _NavLink(
            icon: LucideIcons.heart,
            label: 'Mentale Unterstützung',
            route: '/dashboard/mental-support'),
        _NavLink(
            icon: LucideIcons.lifeBuoy,
            label: 'Rettung',
            route: '/dashboard/rescuer'),
      ],
    ),
    _NavGroup(
      label: 'Module',
      items: [
        _NavLink(
            icon: LucideIcons.bird,
            label: 'Tiere',
            route: '/dashboard/animals'),
        _NavLink(
            icon: LucideIcons.home,
            label: 'Wohnen',
            route: '/dashboard/housing'),
        _NavLink(
            icon: LucideIcons.car,
            label: 'Mobilität',
            route: '/dashboard/mobility'),
        _NavLink(
            icon: LucideIcons.apple,
            label: 'Ernte',
            route: '/dashboard/harvest'),
        _NavLink(
            icon: LucideIcons.shoppingBag,
            label: 'Marktplatz',
            route: '/dashboard/marketplace'),
        _NavLink(
            icon: LucideIcons.leaf,
            label: 'Versorgung',
            route: '/dashboard/supply'),
        _NavLink(
            icon: LucideIcons.share2,
            label: 'Teilen',
            route: '/dashboard/sharing'),
      ],
    ),
    _NavGroup(
      label: 'Wissen & Skills',
      items: [
        _NavLink(
            icon: LucideIcons.bookOpen,
            label: 'Wiki',
            route: '/dashboard/wiki'),
        _NavLink(
            icon: LucideIcons.lightbulb,
            label: 'Wissen',
            route: '/dashboard/knowledge'),
        _NavLink(
            icon: LucideIcons.graduationCap,
            label: 'Skills',
            route: '/dashboard/skills'),
        _NavLink(
            icon: LucideIcons.briefcase,
            label: 'Jobs',
            route: '/dashboard/jobs'),
      ],
    ),
    _NavGroup(
      label: 'Aktivitäten',
      items: [
        _NavLink(
            icon: LucideIcons.calendar,
            label: 'Events',
            route: '/dashboard/events'),
        _NavLink(
            icon: LucideIcons.calendarDays,
            label: 'Kalender',
            route: '/dashboard/calendar'),
        _NavLink(
            icon: LucideIcons.users2,
            label: 'Gruppen',
            route: '/dashboard/groups'),
        _NavLink(
            icon: LucideIcons.pin,
            label: 'Schwarzes Brett',
            route: '/dashboard/board'),
        _NavLink(
            icon: LucideIcons.building2,
            label: 'Organisationen',
            route: '/dashboard/organizations'),
      ],
    ),
    _NavGroup(
      label: 'Mein Engagement',
      items: [
        _NavLink(
            icon: LucideIcons.clock,
            label: 'Zeitbank',
            route: '/dashboard/timebank'),
        _NavLink(
            icon: LucideIcons.trophy,
            label: 'Challenges',
            route: '/dashboard/challenges'),
        _NavLink(
            icon: LucideIcons.award,
            label: 'Badges',
            route: '/dashboard/badges'),
        _NavLink(
            icon: LucideIcons.sparkles,
            label: 'Matching',
            route: '/dashboard/matching'),
        _NavLink(
            icon: LucideIcons.userPlus,
            label: 'Einladen',
            route: '/dashboard/invite'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final isAdmin = profile?.role == 'admin' || profile?.role == 'moderator';

    return Drawer(
      backgroundColor: AppColors.deep,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header: Avatar + Name ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surface,
                    backgroundImage: profile?.avatarUrl != null
                        ? NetworkImage(profile!.avatarUrl!)
                        : null,
                    child: profile?.avatarUrl == null
                        ? Text(
                            (profile?.name ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: AppTypography.display(
                              size: 22,
                              color: AppColors.amber,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.displayName ?? profile?.name ?? 'Nachbar:in',
                    style: AppTypography.display(
                      size: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  if (profile?.location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        profile!.location!,
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.mute,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Nav-Groups ──────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final g in _groups) _GroupTile(group: g),
                  if (isAdmin)
                    const _GroupTile(
                      group: _NavGroup(
                        label: 'Admin',
                        items: [
                          _NavLink(
                            icon: LucideIcons.shield,
                            label: 'Admin-Dashboard',
                            route: '/dashboard/admin',
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: AppColors.line, height: 24),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.user,
                      color: AppColors.inkSoft,
                      size: 18,
                    ),
                    title: Text(
                      'Profil',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/dashboard/profile');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.settings,
                      color: AppColors.inkSoft,
                      size: 18,
                    ),
                    title: Text(
                      'Einstellungen',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/dashboard/settings');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.logOut,
                      color: AppColors.herzrotWarm,
                      size: 18,
                    ),
                    title: Text(
                      'Abmelden',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.herzrotWarm,
                      ),
                    ),
                    onTap: () async {
                      await sb.auth.signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatefulWidget {
  const _GroupTile({required this.group});
  final _NavGroup group;

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.group.label,
                    style: AppTypography.label(
                      size: 10,
                      color: AppColors.mute,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                Icon(
                  _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 14,
                  color: AppColors.mute,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          ...widget.group.items.map(
            (link) => _LinkTile(link: link),
          ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});
  final _NavLink link;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(link.icon, size: 18, color: AppColors.inkSoft),
      ),
      title: Text(
        link.label,
        style: AppTypography.body(
          size: 14,
          color: AppColors.ink,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.go(link.route);
      },
    );
  }
}

class _NavGroup {
  const _NavGroup({required this.label, required this.items});
  final String label;
  final List<_NavLink> items;
}

class _NavLink {
  const _NavLink({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}
