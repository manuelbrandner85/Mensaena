import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Notifications-Repository: Liste, Stream, Unread-Count.
class NotificationsRepository {
  const NotificationsRepository._();

  /// Stream auf alle Notifications des aktuellen Users.
  /// Phase 3 Realtime-Source fuer Bell-Badge + Notification-Liste.
  static Stream<List<AppNotification>> watchMine() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return Stream.value(const []);
    // MEMORY-FIX: .limit(150) — Supabase .stream() ohne Limit lädt ALLE
    // Notifications eines Users (nach Monaten Nutzung: Tausende Rows) in den
    // RAM. 150 reichen für Inbox + History; ältere sind per Scroll nicht
    // erreichbar, aber ein täglicher Cleanup-Cron könnte alte löschen.
    return sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(150)
        .map(
          (rows) => rows
              .map(AppNotification.fromJson)
              .where((n) => n.deletedAt == null)
              .toList(),
        );
  }

  /// Ungelesene Anzahl (Snapshot, kein Stream).
  /// V2: Server-seitiger Count statt alle Rows laden + client-side zaehlen.
  static Future<int> unreadCount() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return 0;
    try {
      final res = await sb
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .filter('read_at', 'is', null)
          .filter('deleted_at', 'is', null)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  /// Test-Notification an den eigenen User (Settings → "Test senden").
  /// Wirft bei Fehler — der Aufrufer zeigt das Feedback.
  static Future<void> insertSelfTest({
    required String title,
    required String message,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await sb.from('notifications').insert({
      'user_id': uid,
      'type': 'system',
      'title': title,
      'message': message,
      'data': {'kind': 'test'},
      'is_read': false,
    });
  }

  /// Eine Notification als gelesen markieren.
  static Future<void> markRead(String id) async {
    try {
      await sb.from('notifications').update({
        'read_at': DateTime.now().toUtc().toIso8601String(),
        'read': true,
      }).eq('id', id);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Alle als gelesen markieren.
  static Future<void> markAllRead() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('notifications')
          .update({
            'read_at': DateTime.now().toUtc().toIso8601String(),
            'read': true,
          })
          .eq('user_id', uid)
          .filter('read_at', 'is', null);
    } catch (_) {}
  }

  /// Einzelne Notification loeschen via RPC delete_notification.
  /// Realtime DELETE-Event entfernt Row automatisch aus dem Stream.
  static Future<bool> delete(String id) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.rpc<dynamic>('delete_notification',
          params: {'p_id': id, 'p_user_id': uid});
      return true;
    } catch (_) {
      // Fallback: direct soft-delete (RPC fehlt eventuell)
      try {
        await sb.from('notifications').update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Alle Notifications soft-deleten via RPC.
  static Future<bool> deleteAll() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.rpc<dynamic>('soft_delete_all_notifications',
          params: {'p_user_id': uid});
      return true;
    } catch (_) {
      try {
        await sb
            .from('notifications')
            .update({
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', uid)
            .filter('deleted_at', 'is', null);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}

/// Realtime-Stream aller Notifications des aktuellen Users.
final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  ref.watch(authStateProvider);
  return NotificationsRepository.watchMine();
});

/// Ungelesene-Anzahl, abgeleitet aus dem Stream.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsStreamProvider).asData?.value ?? [];
  return notifs.where((n) => !n.read && n.readAt == null).length;
});
