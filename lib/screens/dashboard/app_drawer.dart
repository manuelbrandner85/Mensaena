import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
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
  // 1. Notfall & Krise
  _NavGroup(title: 'Notfall & Krise', icon: Icons.warning_amber_outlined, items: [
    _NavItem(label: 'Krisenmeldungen', path: '/dashboard/crisis', icon: Icons.warning_outlined, variant: 'crisis'),
    _NavItem(label: 'Mentale Unterstützung', path: '/dashboard/mental-support', icon: Icons.psychology_outlined),
    _NavItem(label: 'Rettungsnetz', path: '/dashboard/rescuer', icon: Icons.health_and_safety_outlined),
    _NavItem(label: 'Hilfsorganisationen', path: '/dashboard/organizations', icon: Icons.business_outlined),
  ]),
  // 2. Versorgung & Alltag
  _NavGroup(title: 'Versorgung & Alltag', icon: Icons.shopping_bag_outlined, items: [
    _NavItem(label: 'Wohnen & Alltag', path: '/dashboard/housing', icon: Icons.home_outlined),
    _NavItem(label: 'Mobilität', path: '/dashboard/mobility', icon: Icons.directions_car_outlined),
    _NavItem(label: 'Ernte & Hofladen', path: '/dashboard/harvest', icon: Icons.grass_outlined),
    _NavItem(label: 'Versorgung', path: '/dashboard/supply', icon: Icons.inventory_2_outlined),
  ]),
  // 3. Gemeinschaft
  _NavGroup(title: 'Gemeinschaft', icon: Icons.people_outline, items: [
    _NavItem(label: 'Tierhilfe', path: '/dashboard/animals', icon: Icons.pets_outlined),
    _NavItem(label: 'Community', path: '/dashboard/community', icon: Icons.favorite_outline),
    _NavItem(label: 'Teilen & Tauschen', path: '/dashboard/sharing', icon: Icons.swap_horiz),
    _NavItem(label: 'Zeitbank', path: '/dashboard/timebank', icon: Icons.access_time),
    _NavItem(label: 'Skill-Netzwerk', path: '/dashboard/skills', icon: Icons.build_outlined),
    _NavItem(label: 'Matching', path: '/dashboard/matching', icon: Icons.auto_awesome),
  ]),
  // 4. Gruppen & Mehr
  _NavGroup(title: 'Gruppen & Mehr', icon: Icons.grid_view_outlined, items: [
    _NavItem(label: 'Gruppen', path: '/dashboard/groups', icon: Icons.group_outlined),
    _NavItem(label: 'Schwarzes Brett', path: '/dashboard/board', icon: Icons.sticky_note_2_outlined),
    _NavItem(label: 'Events', path: '/dashboard/events', icon: Icons.event_outlined),
    _NavItem(label: 'Kalender', path: '/dashboard/calendar', icon: Icons.calendar_today_outlined),
    _NavItem(label: 'Marktplatz', path: '/dashboard/marketplace', icon: Icons.storefront_outlined),
    _NavItem(label: 'Challenges', path: '/dashboard/challenges', icon: Icons.emoji_events_outlined),
  ]),
  // 5. Wissen & Hilfe
  _NavGroup(title: 'Wissen & Hilfe', icon: Icons.menu_book_outlined, items: [
    _NavItem(label: 'Bildung & Wissen', path: '/dashboard/knowledge', icon: Icons.school_outlined),
    _NavItem(label: 'Wiki', path: '/dashboard/wiki', icon: Icons.menu_book_outlined),
  ]),
  // 6. Persönlich
  _NavGroup(title: 'Persönlich', icon: Icons.account_circle_outlined, items: [
    _NavItem(label: 'Profil', path: '/dashboard/profile', icon: Icons.person_outline),
    _NavItem(label: 'Meine Beiträge', path: '/dashboard/posts', icon: Icons.article_outlined),
    _NavItem(label: 'Interaktionen', path: '/dashboard/interactions', icon: Icons.handshake_outlined),
    _NavItem(label: 'Badges', path: '/dashboard/badges', icon: Icons.military_tech_outlined),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset('assets/images/icon-72x72.png', width: 56, height: 56),
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

            // SOS Emergency Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emergencyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emergency.withOpacity(0.3)),
              ),
              child: ListTile(
                dense: true,
                leading: const Text('\u{1F198}', style: TextStyle(fontSize: 22)),
                title: const Text(
                  'SOS Notruf',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.emergency,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Notfallnummern anzeigen',
                  style: TextStyle(fontSize: 11, color: AppColors.emergency),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.emergency),
                onTap: () => _showSOSDialog(context),
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

            // Chat
            _buildBadgedListTile(
              context: context,
              ref: ref,
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              path: '/dashboard/chat',
              currentPath: currentPath,
              badgeProvider: unreadCountProvider,
            ),

            // Notifications
            _buildBadgedListTile(
              context: context,
              ref: ref,
              icon: Icons.notifications_outlined,
              label: 'Benachrichtigungen',
              path: '/dashboard/notifications',
              currentPath: currentPath,
              badgeProvider: unreadNotificationCountProvider,
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

            // Admin group (only for admin/moderator roles)
            if (_isAdminOrModerator(profile.valueOrNull?.role)) ...[
              const Divider(),
              _DrawerGroup(
                group: const _NavGroup(
                  title: 'Administration',
                  icon: Icons.admin_panel_settings_outlined,
                  items: [
                    _NavItem(label: 'Admin Dashboard', path: '/dashboard/admin', icon: Icons.admin_panel_settings_outlined),
                  ],
                ),
                currentPath: currentPath,
              ),
            ],

            // Donate button
            const Divider(),
            ListTile(
              leading: const Icon(Icons.volunteer_activism, color: AppColors.primary500),
              title: const Text('Spenden', style: TextStyle(color: AppColors.primary500, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://mensaena.de/spenden'));
              },
            ),

            // Logout
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

  bool _isAdminOrModerator(String? role) {
    return role == 'admin' || role == 'moderator';
  }

  Widget _buildBadgedListTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required String path,
    required String currentPath,
    required FutureProvider<int> badgeProvider,
  }) {
    final isSelected = currentPath == path;
    final countAsync = ref.watch(badgeProvider);
    final count = countAsync.valueOrNull ?? 0;

    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary500 : null),
      title: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary500,
      trailing: count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.emergency,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
  }

  void _showSOSDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notfallnummern',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.emergency),
              ),
              const SizedBox(height: 4),
              const Text(
                'Im Notfall sofort anrufen',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              _SOSTile(
                icon: Icons.local_hospital,
                label: 'Notruf / Rettung',
                number: '112',
                onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:112')); },
              ),
              _SOSTile(
                icon: Icons.local_police,
                label: 'Polizei',
                number: '110',
                onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:110')); },
              ),
              _SOSTile(
                icon: Icons.psychology,
                label: 'Telefonseelsorge',
                number: '0800 111 0 111',
                onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:08001110111')); },
              ),
              const SizedBox(height: 12),
            ],
          ),
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
                Icon(widget.group.icon, size: 16,
                  color: _expanded ? AppColors.primary500 : AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.group.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _expanded ? AppColors.primary700 : AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
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
              selectedTileColor: isCrisis ? AppColors.emergencyLight : AppColors.primary50,
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
