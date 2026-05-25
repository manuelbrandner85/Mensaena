/// SKILL: mensaena-features
/// RecentPagesService — pinned + recent routes fuer den Drawer.
///
/// Pendant zu Web localStorage-Pinned/Recent. Speichert via
/// flutter_secure_storage (kein neues Package — bereits in use).
///
/// Pinned: vom User explizit angeheftet via Long-Press auf Drawer-Item.
/// Recent: automatisch befuellt bei jeder Navigation, max 5, dedupe.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RouteMeta {
  const RouteMeta({required this.title, required this.icon});
  final String title; // i18n-key
  final IconData icon;
}

class RecentPagesService {
  const RecentPagesService._();

  static const _pinnedKey = 'mensaena_pinned_routes_v1';
  static const _recentKey = 'mensaena_recent_routes_v1';
  static const _maxRecent = 5;
  static const _storage = FlutterSecureStorage();

  /// Bekannte Routen mit Meta-Daten (Title-Key + Icon). Wenn eine Route
  /// hier fehlt, wird Pfad als Fallback-Title angezeigt.
  static const Map<String, RouteMeta> routeMeta = {
    '/dashboard': RouteMeta(title: 'nav.home', icon: LucideIcons.home),
    '/dashboard/map': RouteMeta(title: 'nav.map', icon: LucideIcons.map),
    '/dashboard/messages':
        RouteMeta(title: 'nav.messages', icon: LucideIcons.mail),
    '/dashboard/chat':
        RouteMeta(title: 'nav.communityChat', icon: LucideIcons.messageCircle),
    '/dashboard/posts':
        RouteMeta(title: 'nav.posts', icon: LucideIcons.fileText),
    '/dashboard/events':
        RouteMeta(title: 'nav.events', icon: LucideIcons.calendar),
    '/dashboard/groups':
        RouteMeta(title: 'nav.groups', icon: LucideIcons.users2),
    '/dashboard/teilen': RouteMeta(
        title: 'navGroups.shareAndResources', icon: LucideIcons.repeat),
    '/dashboard/crisis':
        RouteMeta(title: 'nav.crisis', icon: LucideIcons.alertTriangle),
    '/dashboard/board':
        RouteMeta(title: 'nav.board', icon: LucideIcons.stickyNote),
    '/dashboard/organizations':
        RouteMeta(title: 'nav.organizations', icon: LucideIcons.building2),
    '/dashboard/supply':
        RouteMeta(title: 'nav.supply', icon: LucideIcons.package),
    '/dashboard/harvest':
        RouteMeta(title: 'nav.harvest', icon: LucideIcons.wheat),
    '/dashboard/animals':
        RouteMeta(title: 'nav.animals', icon: LucideIcons.dog),
    '/dashboard/jobs':
        RouteMeta(title: 'nav.jobs', icon: LucideIcons.briefcase),
    '/dashboard/jobs-portals':
        RouteMeta(title: 'jobs.portalsTitle', icon: LucideIcons.briefcase),
    '/dashboard/jobs-search':
        RouteMeta(title: 'jobs.liveSearchTitle', icon: LucideIcons.search),
    '/dashboard/identify':
        RouteMeta(title: 'identify.title', icon: LucideIcons.camera),
    '/dashboard/harvest-wild':
        RouteMeta(title: 'wildPicks.title', icon: LucideIcons.apple),
    '/dashboard/charge-stations':
        RouteMeta(title: 'charge.title', icon: LucideIcons.zap),
    '/dashboard/housing':
        RouteMeta(title: 'nav.housing', icon: LucideIcons.home),
    '/dashboard/mobility':
        RouteMeta(title: 'nav.mobility', icon: LucideIcons.car),
    '/dashboard/wissen':
        RouteMeta(title: 'navGroups.knowledgeAndSkills', icon: LucideIcons.bookOpen),
    '/dashboard/challenges':
        RouteMeta(title: 'nav.challenges', icon: LucideIcons.trophy),
    '/dashboard/badges':
        RouteMeta(title: 'nav.badges', icon: LucideIcons.award),
    '/dashboard/matching':
        RouteMeta(title: 'nav.matching', icon: LucideIcons.sparkles),
    '/dashboard/calendar':
        RouteMeta(title: 'nav.calendar', icon: LucideIcons.calendar),
    '/dashboard/notifications':
        RouteMeta(title: 'nav.notifications', icon: LucideIcons.bell),
    '/dashboard/profile':
        RouteMeta(title: 'nav.profile', icon: LucideIcons.user),
    '/dashboard/settings':
        RouteMeta(title: 'nav.settings', icon: LucideIcons.settings),
    '/dashboard/interactions': RouteMeta(
        title: 'nav.interactions', icon: LucideIcons.helpingHand),
    '/dashboard/mental-support': RouteMeta(
        title: 'nav.mentalSupport', icon: LucideIcons.brain),
    '/dashboard/rescuer':
        RouteMeta(title: 'nav.rescuer', icon: LucideIcons.lifeBuoy),
  };

  static Future<List<String>> _readList(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return const <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> _writeList(String key, List<String> list) async {
    try {
      await _storage.write(key: key, value: jsonEncode(list));
    } catch (_) {/* fail-silent */}
  }

  static Future<List<String>> getPinned() => _readList(_pinnedKey);

  static Future<List<String>> getRecent() => _readList(_recentKey);

  /// True wenn die Route nach dem Toggle gepinned ist.
  static Future<bool> togglePin(String route) async {
    final list = List<String>.from(await _readList(_pinnedKey));
    final isPinned = list.contains(route);
    if (isPinned) {
      list.remove(route);
    } else {
      list.add(route);
    }
    await _writeList(_pinnedKey, list);
    return !isPinned;
  }

  static Future<bool> isPinned(String route) async {
    final list = await _readList(_pinnedKey);
    return list.contains(route);
  }

  /// Fuegt die Route an den Anfang der Recent-Liste, dedupliziert,
  /// trimmt auf maxRecent. Filter: nur Routen die in routeMeta sind
  /// — sonst landen interne Detail-IDs (z.B. /dashboard/posts/<uuid>)
  /// im "Zuletzt"-Bereich, das ist nicht nuetzlich.
  static Future<void> addRecent(String route) async {
    if (!routeMeta.containsKey(route)) return;
    final list = List<String>.from(await _readList(_recentKey));
    list.remove(route);
    list.insert(0, route);
    while (list.length > _maxRecent) {
      list.removeLast();
    }
    await _writeList(_recentKey, list);
  }
}
