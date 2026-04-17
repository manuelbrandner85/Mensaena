import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/notification.dart';

class NotificationService {
  final SupabaseClient _client;
  static const int pageSize = 20;

  NotificationService(this._client);

  Future<List<AppNotification>> getNotifications(
    String userId, {
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .isFilter('deleted_at', null);

      if (type != null) {
        query = query.eq('type', type);
      }

      final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => AppNotification.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount(String userId) async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false)
        .isFilter('deleted_at', null);
    return (data as List).length;
  }

  Future<Map<String, int>> getUnreadCountsByType(String userId) async {
    final data = await _client
        .from('notifications')
        .select('type')
        .eq('user_id', userId)
        .isFilter('read_at', null);

    final counts = <String, int>{};
    for (final row in data) {
      final type = row['type'] as String? ?? 'system';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.from('notifications').update({
      'read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> markAsUnread(String notificationId) async {
    await _client.from('notifications').update({
      'read': false,
      'read_at': null,
    }).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId, {String? type}) async {
    var query = _client
        .from('notifications')
        .update({'read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('read', false);

    if (type != null) {
      query = query.eq('type', type);
    }

    await query;
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> deleteAllNotifications(String userId) async {
    await _client.from('notifications').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId).isFilter('deleted_at', null);
  }

  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(AppNotification) onNotification,
  ) {
    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNotification(AppNotification.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }
}
