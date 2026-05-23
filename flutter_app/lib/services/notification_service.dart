import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/app_config.dart';
import '../config/theme/app_colors.dart';
import 'supabase_service.dart';

/// SKILL: mensaena-features
/// 14 Notification-Kategorien (Spiegel der Web-Logik). Pro Kategorie:
/// Icon (Lucide), Cinema-Farbe, deutsches Label. Preference-Check
/// via shouldNotify() mit In-Memory-Cache (60s TTL).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final Map<String, _PrefCacheEntry> _cache = {};

  /// Kategorien mit Display-Eigenschaften.
  static const Map<String, NotificationStyle> styles = {
    'message': NotificationStyle(
      icon: LucideIcons.messageCircle,
      color: AppColors.teal,
      label: 'Nachricht',
    ),
    'interaction': NotificationStyle(
      icon: LucideIcons.helpingHand,
      color: AppColors.amber,
      label: 'Interaktion',
    ),
    'post_nearby': NotificationStyle(
      icon: LucideIcons.mapPin,
      color: AppColors.leben,
      label: 'In deiner Naehe',
    ),
    'post_response': NotificationStyle(
      icon: LucideIcons.messageSquare,
      color: AppColors.amber,
      label: 'Antwort',
    ),
    'trust_rating': NotificationStyle(
      icon: LucideIcons.star,
      color: AppColors.trust,
      label: 'Bewertung',
    ),
    'system': NotificationStyle(
      icon: LucideIcons.info,
      color: AppColors.inkSoft,
      label: 'System',
    ),
    'bot': NotificationStyle(
      icon: LucideIcons.bot,
      color: AppColors.teal,
      label: 'Mensaena',
    ),
    'mention': NotificationStyle(
      icon: LucideIcons.atSign,
      color: AppColors.amber,
      label: 'Erwaehnung',
    ),
    'welcome': NotificationStyle(
      icon: LucideIcons.heart,
      color: AppColors.herzrot,
      label: 'Willkommen',
    ),
    'reminder': NotificationStyle(
      icon: LucideIcons.bell,
      color: AppColors.amber,
      label: 'Erinnerung',
    ),
    'comment': NotificationStyle(
      icon: LucideIcons.messageSquare,
      color: AppColors.inkSoft,
      label: 'Kommentar',
    ),
    'new_match': NotificationStyle(
      icon: LucideIcons.sparkles,
      color: AppColors.amber,
      label: 'Neuer Match',
    ),
    'match_partner_accepted': NotificationStyle(
      icon: LucideIcons.check,
      color: AppColors.leben,
      label: 'Match akzeptiert',
    ),
    'match_both_accepted': NotificationStyle(
      icon: LucideIcons.checkCheck,
      color: AppColors.leben,
      label: 'Beide akzeptiert',
    ),
    'match_expiring': NotificationStyle(
      icon: LucideIcons.clock,
      color: AppColors.herzrot,
      label: 'Match laeuft ab',
    ),
  };

  static NotificationStyle styleFor(String category) =>
      styles[category] ??
      const NotificationStyle(
        icon: LucideIcons.bell,
        color: AppColors.amber,
        label: 'Nachricht',
      );

  /// Soll der User fuer diese Kategorie benachrichtigt werden?
  /// Liest profiles.notify_* mit 60s-Cache.
  Future<bool> shouldNotify(String category, {String? userId}) async {
    final uid = userId ?? SupabaseService.currentUser?.id;
    if (uid == null) return false;

    final cached = _cache[uid];
    Map<String, dynamic>? prefs;
    if (cached != null && !cached.isExpired) {
      prefs = cached.prefs;
    } else {
      try {
        final row = await sb
            .from('profiles')
            .select('notify_new_messages,notify_new_interactions,'
                'notify_nearby_posts,notify_trust_ratings,notify_system,'
                'notify_inactivity_reminder,notify_email,notify_push')
            .eq('id', uid)
            .maybeSingle();
        prefs = row;
        if (prefs != null) {
          _cache[uid] = _PrefCacheEntry(prefs);
        }
      } catch (_) {
        return true; // fail-open
      }
    }
    if (prefs == null) return true;
    final key = _prefKey(category);
    if (key == null) return true;
    return (prefs[key] as bool?) ?? true;
  }

  static String? _prefKey(String category) {
    switch (category) {
      case 'message':
        return 'notify_new_messages';
      case 'interaction':
      case 'post_response':
        return 'notify_new_interactions';
      case 'post_nearby':
        return 'notify_nearby_posts';
      case 'trust_rating':
        return 'notify_trust_ratings';
      case 'system':
      case 'bot':
      case 'welcome':
        return 'notify_system';
      case 'reminder':
        return 'notify_inactivity_reminder';
      default:
        return null; // unknown — assume allowed
    }
  }

  /// Relative Zeit-Darstellung (Deutsch).
  static String relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays == 1) return 'gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    if (diff.inDays < 30) return 'vor ${diff.inDays ~/ 7} Wochen';
    return '${t.day}.${t.month}.${t.year}';
  }

  void clearCache() => _cache.clear();
}

/// Display-Style fuer eine Notification-Kategorie.
class NotificationStyle {
  const NotificationStyle({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;
}

class _PrefCacheEntry {
  _PrefCacheEntry(this.prefs) : timestamp = DateTime.now();
  final Map<String, dynamic> prefs;
  final DateTime timestamp;
  bool get isExpired =>
      DateTime.now().difference(timestamp).inSeconds >
      AppConfig.notifPrefCacheTtlSec;
}
