import 'package:flutter/material.dart';

import '../routing/routes.dart';

/// 1:1-Übernahme aus src/components/navigation/navigationConfig.ts
/// Reihenfolge, Labels und Icons müssen mit der Web-Sidebar identisch sein.

enum NavBadgeKey {
  unreadMessages,
  unreadNotifications,
  activeCrises,
  suggestedMatches,
  interactionRequests,
}

enum NavVariant { defaultV, crisis, highlight }

class NavItem {
  const NavItem({
    required this.id,
    required this.label,
    required this.path,
    required this.icon,
    this.badgeKey,
    this.variant = NavVariant.defaultV,
    this.comingSoon = false,
  });

  final String id;
  final String label;
  final String path;
  final IconData icon;
  final NavBadgeKey? badgeKey;
  final NavVariant variant;
  final bool comingSoon;
}

class NavGroup {
  const NavGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
    this.adminOnly = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<NavItem> items;
  final bool adminOnly;
}

const mainNavItems = <NavItem>[
  NavItem(id: 'dashboard', label: 'Dashboard', path: Routes.dashboard, icon: Icons.dashboard_outlined),
  NavItem(id: 'create', label: 'Erstellen', path: Routes.dashboardCreate, icon: Icons.add_circle_outline, variant: NavVariant.highlight),
  NavItem(id: 'notifications', label: 'Benachrichtigungen', path: Routes.dashboardNotifications, icon: Icons.notifications_outlined, badgeKey: NavBadgeKey.unreadNotifications),
];

const navGroups = <NavGroup>[
  // 1. Kommunikation
  NavGroup(
    id: 'communication',
    title: 'Kommunikation',
    icon: Icons.chat_bubble_outline,
    items: [
      NavItem(id: 'messages', label: 'Direktnachrichten', path: Routes.dashboardMessages, icon: Icons.mail_outline, badgeKey: NavBadgeKey.unreadMessages),
      NavItem(id: 'chat', label: 'Community Chat', path: Routes.dashboardChat, icon: Icons.forum_outlined),
      NavItem(id: 'matching', label: 'Matching', path: Routes.dashboardMatching, icon: Icons.auto_awesome, badgeKey: NavBadgeKey.suggestedMatches),
    ],
  ),
  // 2. Helfen & Finden
  NavGroup(
    id: 'help',
    title: 'Helfen & Finden',
    icon: Icons.favorite_border,
    items: [
      NavItem(id: 'map', label: 'Karte', path: Routes.dashboardMap, icon: Icons.map_outlined),
      NavItem(id: 'posts', label: 'Hilfe-Posts', path: Routes.dashboardPosts, icon: Icons.description_outlined),
      NavItem(id: 'organizations', label: 'Organisationen', path: Routes.dashboardOrganizations, icon: Icons.business_outlined),
      NavItem(id: 'interactions', label: 'Interaktionen', path: Routes.dashboardInteractions, icon: Icons.handshake_outlined, badgeKey: NavBadgeKey.interactionRequests),
      NavItem(id: 'animals', label: 'Tiere', path: Routes.dashboardAnimals, icon: Icons.pets_outlined),
    ],
  ),
  // 3. Notfall & Sicherheit
  NavGroup(
    id: 'emergency',
    title: 'Notfall & Sicherheit',
    icon: Icons.warning_amber_outlined,
    items: [
      NavItem(id: 'crisis', label: 'Krisenberichte', path: Routes.dashboardCrisis, icon: Icons.warning_amber_outlined, variant: NavVariant.crisis, badgeKey: NavBadgeKey.activeCrises),
      NavItem(id: 'mental-support', label: 'Psychische Unterstützung', path: Routes.dashboardMentalSupport, icon: Icons.psychology_outlined),
    ],
  ),
  // 4. Gemeinschaft
  NavGroup(
    id: 'community',
    title: 'Gemeinschaft',
    icon: Icons.groups_outlined,
    items: [
      NavItem(id: 'groups', label: 'Gruppen', path: Routes.dashboardGroups, icon: Icons.group_work_outlined),
      NavItem(id: 'events', label: 'Veranstaltungen', path: Routes.dashboardEvents, icon: Icons.event_outlined),
      NavItem(id: 'board', label: 'Pinnwand', path: Routes.dashboardBoard, icon: Icons.sticky_note_2_outlined),
      NavItem(id: 'challenges', label: 'Challenges', path: Routes.dashboardChallenges, icon: Icons.emoji_events_outlined),
    ],
  ),
  // 5. Teilen & Ressourcen
  NavGroup(
    id: 'sharing',
    title: 'Teilen & Ressourcen',
    icon: Icons.swap_horiz,
    items: [
      NavItem(id: 'sharing', label: 'Teilen', path: Routes.dashboardSharing, icon: Icons.share_outlined),
      NavItem(id: 'timebank', label: 'Zeitbank', path: Routes.dashboardTimebank, icon: Icons.access_time),
      NavItem(id: 'marketplace', label: 'Marktplatz', path: Routes.dashboardMarketplace, icon: Icons.store_outlined),
      NavItem(id: 'supply', label: 'Vorrat', path: Routes.dashboardSupply, icon: Icons.inventory_2_outlined),
      NavItem(id: 'harvest', label: 'Ernte', path: Routes.dashboardHarvest, icon: Icons.agriculture_outlined),
      NavItem(id: 'rescuer', label: 'Lebensretter', path: Routes.dashboardRescuer, icon: Icons.medical_services_outlined),
      NavItem(id: 'housing', label: 'Wohnen', path: Routes.dashboardHousing, icon: Icons.home_outlined),
      NavItem(id: 'mobility', label: 'Mobilität', path: Routes.dashboardMobility, icon: Icons.directions_car_outlined),
      NavItem(id: 'jobs', label: 'Jobs', path: Routes.dashboardJobs, icon: Icons.work_outline),
    ],
  ),
  // 6. Wissen & Skills
  NavGroup(
    id: 'knowledge',
    title: 'Wissen & Skills',
    icon: Icons.menu_book_outlined,
    items: [
      NavItem(id: 'wiki', label: 'Wiki', path: Routes.dashboardWiki, icon: Icons.book_outlined),
      NavItem(id: 'knowledge', label: 'Bildung', path: Routes.dashboardKnowledge, icon: Icons.school_outlined),
      NavItem(id: 'skills', label: 'Skills', path: Routes.dashboardSkills, icon: Icons.build_outlined),
    ],
  ),
  // 7. Mein Bereich
  NavGroup(
    id: 'personal',
    title: 'Mein Bereich',
    icon: Icons.person_outline,
    items: [
      NavItem(id: 'profile', label: 'Profil', path: Routes.dashboardProfile, icon: Icons.account_circle_outlined),
      NavItem(id: 'invite', label: 'Nachbarn einladen', path: Routes.dashboardInvite, icon: Icons.share, variant: NavVariant.highlight),
      NavItem(id: 'badges', label: 'Abzeichen', path: Routes.dashboardBadges, icon: Icons.military_tech_outlined),
      NavItem(id: 'calendar', label: 'Kalender', path: Routes.dashboardCalendar, icon: Icons.calendar_today_outlined),
      NavItem(id: 'settings', label: 'Einstellungen', path: Routes.dashboardSettings, icon: Icons.settings_outlined),
    ],
  ),
  // Admin
  NavGroup(
    id: 'admin',
    title: 'Admin',
    icon: Icons.shield_outlined,
    adminOnly: true,
    items: [
      NavItem(id: 'admin', label: 'Admin Dashboard', path: Routes.dashboardAdmin, icon: Icons.shield_outlined),
    ],
  ),
];

// Bottom Nav (5 Items, Reihenfolge identisch zu navigationConfig.ts)
const bottomNavItems = <NavItem>[
  NavItem(id: 'dashboard', label: 'Home', path: Routes.dashboard, icon: Icons.home_outlined),
  NavItem(id: 'map', label: 'Karte', path: Routes.dashboardMap, icon: Icons.map_outlined),
  NavItem(id: 'create', label: 'Erstellen', path: Routes.dashboardCreate, icon: Icons.add_circle, variant: NavVariant.highlight),
  NavItem(id: 'messages', label: 'Chat', path: Routes.dashboardMessages, icon: Icons.chat_bubble_outline, badgeKey: NavBadgeKey.unreadMessages),
  NavItem(id: 'notifications', label: 'Benachr.', path: Routes.dashboardNotifications, icon: Icons.notifications_outlined, badgeKey: NavBadgeKey.unreadNotifications),
];
