import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

class _NavGroup {
  final String title;
  final IconData icon;
  final List<_NavItem> items;

  const _NavGroup({required this.title, required this.icon, required this.items});
}

class _NavItem {
  final String label;
  final String path;
  final IconData icon;
  final String? variant;

  const _NavItem({required this.label, required this.path, required this.icon, this.variant});
}

const _navGroups = [
  _NavGroup(title: 'Kommunikation', icon: Icons.chat_bubble_outline, items: [
    _NavItem(label: 'Direktnachrichten', path: '/dashboard/messages', icon: Icons.mail_outline),
    _NavItem(label: 'Community-Chat', path: '/dashboard/chat', icon: Icons.forum_outlined),
    _NavItem(label: 'Matching', path: '/dashboard/matching', icon: Icons.auto_awesome),
  ]),
  _NavGroup(title: 'Helfen & Finden', icon: Icons.favorite_outline, items: [
    _NavItem(label: 'Karte', path: '/dashboard/map', icon: Icons.map_outlined),
    _NavItem(label: 'Beiträge', path: '/dashboard/posts', icon: Icons.article_outlined),
    _NavItem(label: 'Hilfsorganisationen', path: '/dashboard/organizations', icon: Icons.business_outlined),
    _NavItem(label: 'Interaktionen', path: '/dashboard/interactions', icon: Icons.handshake_outlined),
  ]),
  _NavGroup(title: 'Notfall & Sicherheit', icon: Icons.warning_amber_outlined, items: [
    _NavItem(label: 'Krisenmeldungen', path: '/dashboard/crisis', icon: Icons.warning_outlined, variant: 'crisis'),
    _NavItem(label: 'Mentale Unterstützung', path: '/dashboard/mental-support', icon: Icons.psychology_outlined),
    _NavItem(label: 'Rettungsnetz', path: '/dashboard/rescuer', icon: Icons.health_and_safety_outlined),
  ]),
  _NavGroup(title: 'Gemeinschaft', icon: Icons.people_outline, items: [
    _NavItem(label: 'Community', path: '/dashboard/community', icon: Icons.favorite_outline),
    _NavItem(label: 'Gruppen', path: '/dashboard/groups', icon: Icons.group_outlined),
    _NavItem(label: 'Events', path: '/dashboard/events', icon: Icons.event_outlined),
    _NavItem(label: 'Schwarzes Brett', path: '/dashboard/board', icon: Icons.sticky_note_2_outlined),
    _NavItem(label: 'Challenges', path: '/dashboard/challenges', icon: Icons.emoji_events_outlined),
  ]),
  _NavGroup(title: 'Teilen & Versorgen', icon: Icons.swap_horiz, items: [
    _NavItem(label: 'Teilen & Tauschen', path: '/dashboard/sharing', icon: Icons.swap_horiz),
    _NavItem(label: 'Zeitbank', path: '/dashboard/timebank', icon: Icons.access_time),
    _NavItem(label: 'Marktplatz', path: '/dashboard/marketplace', icon: Icons.storefront_outlined),
    _NavItem(label: 'Regionale Versorgung', path: '/dashboard/supply', icon: Icons.inventory_2_outlined),
    _NavItem(label: 'Ernte & Hofladen', path: '/dashboard/harvest', icon: Icons.grass_outlined),
  ]),
  _NavGroup(title: 'Wissen & Engagement', icon: Icons.school_outlined, items: [
    _NavItem(label: 'Wiki', path: '/dashboard/wiki', icon: Icons.menu_book_outlined),
    _NavItem(label: 'Bildung & Kurse', path: '/dashboard/knowledge', icon: Icons.school_outlined),
    _NavItem(label: 'Skill-Netzwerk', path: '/dashboard/skills', icon: Icons.build_outlined),
    _NavItem(label: 'Tierhilfe', path: '/dashboard/animals', icon: Icons.pets_outlined),
  ]),
  _NavGroup(title: 'Mein Bereich', icon: Icons.person_outline, items: [
    _NavItem(label: 'Profil', path: '/dashboard/profile', icon: Icons.person_outline),
    _NavItem(label: 'Badges', path: '/dashboard/badges', icon: Icons.military_tech_outlined),
    _NavItem(label: 'Wohnen', path: '/dashboard/housing', icon: Icons.home_outlined),
    _NavItem(label: 'Mobilität', path: '/dashboard/mobility', icon: Icons.directions_car_outlined),
    _NavItem(label: 'Kalender', path: '/dashboard/calendar', icon: Icons.calendar_today_outlined),
    _NavItem(label: 'Einstellungen', path: '/dashboard/settings', icon: Icons.settings_outlined),
  ]),
];

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header with Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary500, AppColors.primary700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/images/icon-72x72.png', width: 40, height: 40),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Mensaena',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: profile.valueOrNull?.avatarUrl,
                        name: profile.valueOrNull?.displayName ?? 'M',
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.valueOrNull?.displayName ?? 'Gast',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                            ),
                            const Text(
                              'Nachbarschaftshilfe',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Dashboard Link
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              selected: currentPath == '/dashboard',
              selectedColor: AppColors.primary500,
              onTap: () {
                Navigator.pop(context);
                context.go('/dashboard');
              },
            ),

            // Notifications
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Benachrichtigungen'),
              selected: currentPath == '/dashboard/notifications',
              selectedColor: AppColors.primary500,
              onTap: () {
                Navigator.pop(context);
                context.go('/dashboard/notifications');
              },
            ),

            const Divider(),

            // Navigation Groups
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _navGroups.map((group) {
                  return _DrawerGroup(
                    group: group,
                    currentPath: currentPath,
                  );
                }).toList(),
              ),
            ),

            // Logout
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Abmelden', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/auth/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerGroup extends StatefulWidget {
  final _NavGroup group;
  final String currentPath;

  const _DrawerGroup({required this.group, required this.currentPath});

  @override
  State<_DrawerGroup> createState() => _DrawerGroupState();
}

class _DrawerGroupState extends State<_DrawerGroup> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.items.any((item) => widget.currentPath == item.path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(widget.group.icon, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.group.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.group.items.map((item) {
            final isSelected = widget.currentPath == item.path;
            final isCrisis = item.variant == 'crisis';

            return ListTile(
              dense: true,
              leading: Icon(
                item.icon,
                size: 20,
                color: isCrisis
                    ? AppColors.emergency
                    : isSelected
                        ? AppColors.primary500
                        : AppColors.textSecondary,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  color: isCrisis
                      ? AppColors.emergency
                      : isSelected
                          ? AppColors.primary500
                          : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedTileColor: AppColors.primary50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.only(left: 44, right: 16),
              onTap: () {
                Navigator.pop(context);
                context.go(item.path);
              },
            );
          }),
      ],
    );
  }
}
