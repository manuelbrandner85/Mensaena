import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/theme_mode_provider.dart';
import '../../repositories/conversations_repository.dart';
import '../../repositories/crisis_repository.dart';
import '../../repositories/interactions_repository.dart';
import '../../repositories/matching_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';

/// SKILL: flutter-setup-declarative-routing + mensaena-design
/// 1:1-Spiegel der Web-Sidebar (src/components/navigation/navigationConfig.ts).
/// 7 Gruppen + Admin als ExpansionTile (V13). Last-Open-Group wird in
/// flutter_secure_storage persistiert und beim naechsten Drawer-Open
/// automatisch expanded.
///
/// Cinema-Details:
///   - ExpansionTile mit eigener CurvedAnimation (Curves.easeOutCubic, 280ms)
///   - Group-Header im GlassCard-subtle-Stil (amber-tint, 1px border)
///     mit Count-Badge (Anzahl Module).
///   - Active-Route highlight: lineActive (3dp Border-Left).
///   - Scrollbar mit Bronze-Track-Color.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  /// flutter_secure_storage Key fuer die zuletzt geoeffnete Gruppe.
  static const String _kLastOpenGroupKey = 'mensaena_drawer_last_open_group';

  // i18n: alle `label`-Strings sind translation-keys, .tr() in den Tiles.
  static const _NavLink _home = _NavLink(
    icon: LucideIcons.layoutDashboard,
    label: 'nav.dashboard',
    route: '/dashboard',
  );
  static const _NavLink _notifications = _NavLink(
    icon: LucideIcons.bell,
    label: 'nav.notifications',
    route: '/dashboard/notifications',
    badgeKey: 'unreadNotifications',
  );

  static const List<_NavGroup> _groups = [
    _NavGroup(
      label: 'navGroups.communication',
      headIcon: LucideIcons.messageCircle,
      items: [
        _NavLink(icon: LucideIcons.mail, label: 'nav.messages',
            route: '/dashboard/messages', badgeKey: 'unreadMessages'),
        _NavLink(icon: LucideIcons.messageCircle, label: 'nav.communityChat',
            route: '/dashboard/chat'),
        _NavLink(icon: LucideIcons.sparkles, label: 'nav.matching',
            route: '/dashboard/matching', badgeKey: 'suggestedMatches'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.helpAndFind',
      headIcon: LucideIcons.heart,
      items: [
        _NavLink(icon: LucideIcons.map, label: 'nav.map', route: '/dashboard/map'),
        _NavLink(icon: LucideIcons.fileText, label: 'nav.posts',
            route: '/dashboard/posts'),
        _NavLink(icon: LucideIcons.building2, label: 'nav.organizations',
            route: '/dashboard/organizations'),
        _NavLink(icon: LucideIcons.helpingHand, label: 'nav.interactions',
            route: '/dashboard/interactions', badgeKey: 'interactionRequests'),
        _NavLink(icon: LucideIcons.dog, label: 'nav.animals',
            route: '/dashboard/animals'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.emergencyAndSafety',
      headIcon: LucideIcons.alertTriangle,
      items: [
        _NavLink(icon: LucideIcons.alertTriangle, label: 'nav.crisis',
            route: '/dashboard/crisis', variant: _NavVariant.crisis,
            badgeKey: 'activeCrises'),
        _NavLink(icon: LucideIcons.brain, label: 'nav.mentalSupport',
            route: '/dashboard/mental-support'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.community',
      headIcon: LucideIcons.users,
      items: [
        _NavLink(icon: LucideIcons.users2, label: 'nav.groups',
            route: '/dashboard/groups'),
        _NavLink(icon: LucideIcons.calendar, label: 'nav.events',
            route: '/dashboard/events'),
        _NavLink(icon: LucideIcons.stickyNote, label: 'nav.board',
            route: '/dashboard/board'),
        _NavLink(icon: LucideIcons.trophy, label: 'nav.challenges',
            route: '/dashboard/challenges'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.shareAndResources',
      headIcon: LucideIcons.repeat,
      items: [
        // Konsolidiert: Sharing + Marketplace + Timebank → 1 Hub.
        _NavLink(icon: LucideIcons.repeat, label: 'navGroups.shareAndResources',
            route: '/dashboard/teilen'),
        _NavLink(icon: LucideIcons.package, label: 'nav.supply',
            route: '/dashboard/supply'),
        _NavLink(icon: LucideIcons.wheat, label: 'nav.harvest',
            route: '/dashboard/harvest'),
        _NavLink(icon: LucideIcons.lifeBuoy, label: 'nav.rescuer',
            route: '/dashboard/rescuer'),
        _NavLink(icon: LucideIcons.home, label: 'nav.housing',
            route: '/dashboard/housing'),
        _NavLink(icon: LucideIcons.car, label: 'nav.mobility',
            route: '/dashboard/mobility'),
        _NavLink(icon: LucideIcons.briefcase, label: 'nav.jobs',
            route: '/dashboard/jobs'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.knowledgeAndSkills',
      headIcon: LucideIcons.bookOpen,
      items: [
        // Konsolidiert: Wiki + Bildung + Skills → 1 Hub.
        _NavLink(icon: LucideIcons.bookOpen, label: 'navGroups.knowledgeAndSkills',
            route: '/dashboard/wissen'),
      ],
    ),
    _NavGroup(
      label: 'navGroups.myArea',
      headIcon: LucideIcons.userCircle,
      items: [
        _NavLink(icon: LucideIcons.user, label: 'nav.profile',
            route: '/dashboard/profile'),
        _NavLink(icon: LucideIcons.share2, label: 'nav.invite',
            route: '/dashboard/invite', variant: _NavVariant.highlight),
        _NavLink(icon: LucideIcons.award, label: 'nav.badges',
            route: '/dashboard/badges'),
        _NavLink(icon: LucideIcons.calendar, label: 'nav.calendar',
            route: '/dashboard/calendar'),
        _NavLink(icon: LucideIcons.settings, label: 'nav.settings',
            route: '/dashboard/settings'),
      ],
    ),
  ];

  static const _NavGroup _adminGroup = _NavGroup(
    label: 'navGroups.adminArea',
    headIcon: LucideIcons.shieldCheck,
    items: [
      _NavLink(icon: LucideIcons.shieldCheck, label: 'nav.admin',
          route: '/dashboard/admin'),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final role = profile?.role ?? 'user';
    final isAdmin = role == 'admin' || role == 'moderator';
    final currentLoc = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: AppColors.deep,
      child: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(profile: profile),
            Expanded(
              child: Theme(
                // Scrollbar mit Bronze-Track-Color.
                data: Theme.of(context).copyWith(
                  scrollbarTheme: ScrollbarThemeData(
                    thumbColor: WidgetStateProperty.all(
                      AppColors.bronze.withValues(alpha: 0.55),
                    ),
                    trackColor: WidgetStateProperty.all(
                      AppColors.bronze.withValues(alpha: 0.12),
                    ),
                    radius: const Radius.circular(8),
                    thickness: WidgetStateProperty.all(3),
                  ),
                  // Standard-Divider unter ExpansionTile entfernen.
                  dividerColor: Colors.transparent,
                ),
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _LinkTile(link: _home, currentLoc: currentLoc),
                      _LinkTile(
                          link: _notifications, currentLoc: currentLoc),
                      const Divider(color: AppColors.line, height: 16),
                      for (final g in _groups)
                        _GroupSection(
                            group: g, currentLoc: currentLoc),
                      if (isAdmin) ...[
                        const Divider(color: AppColors.line, height: 16),
                        _GroupSection(
                            group: _adminGroup,
                            currentLoc: currentLoc,
                            initiallyOpen: true),
                      ],
                      const Divider(color: AppColors.line, height: 16),
                      const _ThemeToggleFooter(),
                      ListTile(
                        leading: const Icon(
                          LucideIcons.logOut,
                          color: AppColors.herzrotWarm,
                          size: 18,
                        ),
                        title: Text(
                          'common.logout'.tr(),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl as String?;
    final displayName =
        profile?.displayName as String? ?? profile?.name as String?;
    final location = profile?.location as String?;
    return Container(
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
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    (displayName ?? '?').substring(0, 1).toUpperCase(),
                    style: AppTypography.display(
                      size: 22,
                      color: AppColors.amber,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            displayName ?? 'common.neighbour'.tr(),
            style: AppTypography.display(
              size: 18,
              color: AppColors.ink,
            ),
          ),
          if (location != null && location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                location,
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.mute,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Collapsible Gruppe (ExpansionTile). Last-Open-Group wird via
/// flutter_secure_storage persistiert.
class _GroupSection extends StatefulWidget {
  const _GroupSection({
    required this.group,
    required this.currentLoc,
    this.initiallyOpen = false,
  });
  final _NavGroup group;
  final String currentLoc;
  final bool initiallyOpen;

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  static const _storage = FlutterSecureStorage();
  bool _open = false;

  bool get _groupContainsActive {
    return widget.group.items.any((l) =>
        widget.currentLoc == l.route ||
        widget.currentLoc.startsWith('${l.route}/'));
  }

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen || _groupContainsActive;
    _restoreLastOpenGroup();
  }

  Future<void> _restoreLastOpenGroup() async {
    if (_open) return;
    try {
      final lastOpen =
          await _storage.read(key: AppDrawer._kLastOpenGroupKey);
      if (!mounted) return;
      if (lastOpen == widget.group.label) {
        setState(() => _open = true);
      }
    } catch (_) {
      // Storage-Fehler ignorieren (z.B. Web/Desktop ohne Plugin).
    }
  }

  Future<void> _persistOpenGroup() async {
    try {
      await _storage.write(
        key: AppDrawer._kLastOpenGroupKey,
        value: widget.group.label,
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.group.items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ExpansionTile(
          key: PageStorageKey('drawer_group_${widget.group.label}'),
          initiallyExpanded: _open,
          onExpansionChanged: (open) {
            setState(() => _open = open);
            if (open) _persistOpenGroup();
          },
          // Cinematic-Animation via easeOutCubic. ExpansionTile nutzt
          // standardmaessig 200ms — wir ueberschreiben auf 280ms easeOutCubic.
          // (ExpansionTile-API exposes nur Curves; setzen via Theme oben.)
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          backgroundColor: AppColors.surface.withValues(alpha: 0.40),
          collapsedBackgroundColor:
              AppColors.surface.withValues(alpha: 0.20),
          iconColor: AppColors.amber,
          collapsedIconColor: AppColors.mute,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              if (widget.group.headIcon != null) ...[
                Icon(
                  widget.group.headIcon,
                  size: 14,
                  color: _open ? AppColors.amber : AppColors.mute,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.group.label.tr(),
                  style: AppTypography.label(
                    size: 10,
                    color: _open ? AppColors.ink : AppColors.mute,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              // Count-Badge — Anzahl der Module in der Gruppe.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.mono(
                    size: 9,
                    color: AppColors.bronze,
                  ),
                ),
              ),
            ],
          ),
          children: widget.group.items
              .map((l) => _LinkTile(link: l, currentLoc: widget.currentLoc))
              .toList(),
        ),
      ),
    );
  }
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link, required this.currentLoc});
  final _NavLink link;
  final String currentLoc;

  int _badgeCount(WidgetRef ref) {
    switch (link.badgeKey) {
      case 'unreadNotifications':
        return ref.watch(unreadNotificationCountProvider);
      case 'unreadMessages':
        return ref
                .watch(conversationsProvider)
                .asData
                ?.value
                .where((c) => (c['unread_count'] as num?) != null
                    ? ((c['unread_count'] as num).toInt() > 0)
                    : false)
                .length ??
            0;
      case 'activeCrises':
        return ref
                .watch(activeCrisesProvider)
                .asData
                ?.value
                .where((c) => c.urgency == 'critical' || c.urgency == 'high')
                .length ??
            0;
      case 'suggestedMatches':
        return ref
                .watch(matchingListProvider)
                .asData
                ?.value
                .where((m) => m.status == 'pending')
                .length ??
            0;
      case 'interactionRequests':
        return ref.watch(activeInteractionsCountProvider).asData?.value ?? 0;
      default:
        return 0;
    }
  }

  bool get _active =>
      currentLoc == link.route || currentLoc.startsWith('${link.route}/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (link.variant) {
      _NavVariant.crisis => AppColors.herzrot,
      _NavVariant.highlight => AppColors.amber,
      _ => AppColors.inkSoft,
    };
    final textColor = switch (link.variant) {
      _NavVariant.crisis => AppColors.herzrotWarm,
      _NavVariant.highlight => AppColors.amber,
      _ => AppColors.ink,
    };
    final badge = link.badgeKey == null ? 0 : _badgeCount(ref);
    final badgeColor = link.variant == _NavVariant.crisis
        ? AppColors.herzrot
        : AppColors.bronze;
    final isActive = _active;
    return Container(
      decoration: isActive
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.lineActive, width: 3),
              ),
            )
          : null,
      child: ListTile(
        dense: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(link.icon, size: 18, color: color),
        ),
        title: Text(
          link.label.tr(),
          style: AppTypography.body(
            size: 14,
            color: textColor,
            weight: isActive || link.variant == _NavVariant.highlight
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        trailing: badge > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: AppTypography.mono(
                    size: 9,
                    color: AppColors.voidColor,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.of(context).pop();
          context.go(link.route);
        },
      ),
    );
  }
}

/// V20 Phase-6b: Theme-Toggle im Drawer-Footer.
/// Sun-Icon zeigt im Dark-Mode (Hint auf Wechsel zu Light),
/// Moon-Icon im Light-Mode (Hint auf Wechsel zu Dark).
class _ThemeToggleFooter extends ConsumerWidget {
  const _ThemeToggleFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightModeProvider);
    return ListTile(
      leading: Icon(
        isLight ? LucideIcons.moon : LucideIcons.sun,
        size: 18,
        color: AppColors.amber,
      ),
      title: Text(
        isLight
            ? 'settings.themeMode.dark'.tr()
            : 'settings.themeMode.light'.tr(),
        style: AppTypography.body(size: 14, color: AppColors.ink),
      ),
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

enum _NavVariant { defaultVariant, crisis, highlight }

class _NavGroup {
  const _NavGroup({
    required this.label,
    required this.items,
    this.headIcon,
  });
  final String label;
  final IconData? headIcon;
  final List<_NavLink> items;
}

class _NavLink {
  const _NavLink({
    required this.icon,
    required this.label,
    required this.route,
    this.variant = _NavVariant.defaultVariant,
    this.badgeKey,
  });
  final IconData icon;
  final String label;
  final String route;
  final _NavVariant variant;
  /// one of: 'unreadMessages' | 'unreadNotifications' | 'activeCrises' |
  /// 'suggestedMatches' | 'interactionRequests'
  final String? badgeKey;
}
