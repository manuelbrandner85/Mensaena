/// SKILL: mensaena-features + supabase
/// user_notification_prefs — Master + 6 Type-Toggles + Quiet-Hours.
/// 1:1 zum gleichnamigen Konzept der Weltenbibliothek-App.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

class NotifPrefs {
  const NotifPrefs({
    required this.enabled,
    required this.chat,
    required this.social,
    required this.system,
    required this.crisis,
    required this.marketplace,
    required this.events,
    required this.quietHoursEnabled,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.quietAllowCritical,
  });

  final bool enabled;
  final bool chat;
  final bool social;
  final bool system;
  final bool crisis;
  final bool marketplace;
  final bool events;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;
  final bool quietAllowCritical;

  static const NotifPrefs defaults = NotifPrefs(
    enabled: true,
    chat: true,
    social: true,
    system: true,
    crisis: true,
    marketplace: true,
    events: true,
    quietHoursEnabled: false,
    quietStartHour: 22,
    quietEndHour: 7,
    quietAllowCritical: true,
  );

  factory NotifPrefs.fromMap(Map<String, dynamic> m) => NotifPrefs(
        enabled: m['enabled'] as bool? ?? true,
        chat: m['chat'] as bool? ?? true,
        social: m['social'] as bool? ?? true,
        system: m['system'] as bool? ?? true,
        crisis: m['crisis'] as bool? ?? true,
        marketplace: m['marketplace'] as bool? ?? true,
        events: m['events'] as bool? ?? true,
        quietHoursEnabled: m['quiet_hours_enabled'] as bool? ?? false,
        quietStartHour: (m['quiet_start_hour'] as num?)?.toInt() ?? 22,
        quietEndHour: (m['quiet_end_hour'] as num?)?.toInt() ?? 7,
        quietAllowCritical: m['quiet_allow_critical'] as bool? ?? true,
      );

  NotifPrefs copyWith({
    bool? enabled,
    bool? chat,
    bool? social,
    bool? system,
    bool? crisis,
    bool? marketplace,
    bool? events,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    bool? quietAllowCritical,
  }) =>
      NotifPrefs(
        enabled: enabled ?? this.enabled,
        chat: chat ?? this.chat,
        social: social ?? this.social,
        system: system ?? this.system,
        crisis: crisis ?? this.crisis,
        marketplace: marketplace ?? this.marketplace,
        events: events ?? this.events,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
        quietAllowCritical: quietAllowCritical ?? this.quietAllowCritical,
      );

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'enabled': enabled,
        'chat': chat,
        'social': social,
        'system': system,
        'crisis': crisis,
        'marketplace': marketplace,
        'events': events,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_start_hour': quietStartHour,
        'quiet_end_hour': quietEndHour,
        'quiet_allow_critical': quietAllowCritical,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class NotificationPrefsRepository {
  const NotificationPrefsRepository._();

  static Future<NotifPrefs> getMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return NotifPrefs.defaults;
    try {
      final row = await sb
          .from('user_notification_prefs')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return NotifPrefs.defaults;
      return NotifPrefs.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return NotifPrefs.defaults;
    }
  }

  static Future<bool> save(NotifPrefs prefs) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('user_notification_prefs').upsert(prefs.toUpsertMap(uid));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final myNotifPrefsProvider = FutureProvider<NotifPrefs>((ref) async {
  return NotificationPrefsRepository.getMine();
});
