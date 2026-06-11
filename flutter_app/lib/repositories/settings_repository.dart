/// SKILL: mensaena-features + supabase
/// SettingsRepository — liest und schreibt notification_preferences
/// (JSONB in profiles) für die 5 Feature-Kategorien.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.messages,
    required this.interactions,
    required this.zeitbank,
    required this.crisis,
    required this.marketing,
  });

  final bool messages;
  final bool interactions;
  final bool zeitbank;
  final bool crisis;
  final bool marketing;

  static const NotificationPreferences defaults = NotificationPreferences(
    messages: true,
    interactions: true,
    zeitbank: true,
    crisis: true,
    marketing: false,
  );

  factory NotificationPreferences.fromMap(Map<String, dynamic> m) =>
      NotificationPreferences(
        messages: m['messages'] as bool? ?? true,
        interactions: m['interactions'] as bool? ?? true,
        zeitbank: m['zeitbank'] as bool? ?? true,
        crisis: m['crisis'] as bool? ?? true,
        marketing: m['marketing'] as bool? ?? false,
      );

  NotificationPreferences copyWith({
    bool? messages,
    bool? interactions,
    bool? zeitbank,
    bool? crisis,
    bool? marketing,
  }) =>
      NotificationPreferences(
        messages: messages ?? this.messages,
        interactions: interactions ?? this.interactions,
        zeitbank: zeitbank ?? this.zeitbank,
        crisis: crisis ?? this.crisis,
        marketing: marketing ?? this.marketing,
      );

  Map<String, dynamic> toMap() => {
        'messages': messages,
        'interactions': interactions,
        'zeitbank': zeitbank,
        'crisis': crisis,
        'marketing': marketing,
      };
}

class SettingsRepository {
  const SettingsRepository._();

  static Future<NotificationPreferences> getNotificationPreferences() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return NotificationPreferences.defaults;
    try {
      final row = await sb
          .from('profiles')
          .select('notification_preferences')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return NotificationPreferences.defaults;
      final raw = row['notification_preferences'];
      if (raw == null) return NotificationPreferences.defaults;
      return NotificationPreferences.fromMap(
          Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return NotificationPreferences.defaults;
    }
  }

  static Future<bool> saveNotificationPreferences(
      NotificationPreferences prefs) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('profiles')
          .update({'notification_preferences': prefs.toMap()}).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DSGVO-Art.-20-Export: alle Rows einer Tabelle, in denen der User in
  /// EINER Spalte steht. Fehler → leere Liste (Export bleibt vollständig
  /// lauffähig, auch wenn einzelne Tabellen/RLS-Policies fehlen).
  static Future<List<dynamic>> gdprRowsSingle(
      String table, String column, String uid) async {
    try {
      return await sb.from(table).select().eq(column, uid).limit(10000);
    } catch (_) {
      return const <dynamic>[];
    }
  }

  /// DSGVO-Export für Tabellen mit ZWEI beteiligten Spalten
  /// (beide Richtungen, z. B. interactions helper_id/helped_id).
  static Future<List<dynamic>> gdprRowsDual(
      String table, String columnA, String columnB, String uid) async {
    try {
      return await sb
          .from(table)
          .select()
          .or('$columnA.eq.$uid,$columnB.eq.$uid')
          .limit(10000);
    } catch (_) {
      return const <dynamic>[];
    }
  }

  /// Liest die drei DSGVO-Opt-in-Flags. null-Werte → false
  /// (Privacy by default: fehlender Wert = NICHT eingewilligt).
  static Future<({bool marketing, bool reactivation, bool email})>
      getConsentFlags(String uid) async {
    final row = await sb
        .from('profiles')
        .select('marketing_opt_in, reactivation_opt_in, email_opt_in')
        .eq('id', uid)
        .maybeSingle();
    return (
      marketing: (row?['marketing_opt_in'] as bool?) ?? false,
      reactivation: (row?['reactivation_opt_in'] as bool?) ?? false,
      email: (row?['email_opt_in'] as bool?) ?? false,
    );
  }

  /// E-Mail-Abmeldung (Opt-out): markiert die email_subscriptions-Zeile
  /// als abgemeldet. Das profiles-Flag setzt der Aufrufer via
  /// ProfilesRepository.update (eine Zuständigkeit pro Repo).
  static Future<void> unsubscribeEmail(String uid) async {
    await sb.from('email_subscriptions').update({
      'subscribed': false,
      'unsubscribed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', uid);
  }
}

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  return SettingsRepository.getNotificationPreferences();
});
