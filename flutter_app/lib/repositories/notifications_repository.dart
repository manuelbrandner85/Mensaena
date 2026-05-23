import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .map(
          (rows) => rows
              .map(AppNotification.fromJson)
              .where((n) => n.deletedAt == null)
              .toList()
              .reversed
              .toList(),
        );
  }

  /// Ungelesene Anzahl (Snapshot, kein Stream).
  static Future<int> unreadCount() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return 0;
    try {
      final rows = await sb
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .filter('read_at', 'is', null)
          .filter('deleted_at', 'is', null);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
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
