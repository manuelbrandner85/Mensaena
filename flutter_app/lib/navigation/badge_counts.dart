import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import 'nav_config.dart';

/// Provider für Badge-Counts in der Navigation. 1:1-Pendant zur Web-App.
class BadgeCounts {
  const BadgeCounts({
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.activeCrises = 0,
    this.suggestedMatches = 0,
    this.interactionRequests = 0,
  });

  final int unreadMessages;
  final int unreadNotifications;
  final int activeCrises;
  final int suggestedMatches;
  final int interactionRequests;

  int forKey(NavBadgeKey? key) {
    switch (key) {
      case NavBadgeKey.unreadMessages:
        return unreadMessages;
      case NavBadgeKey.unreadNotifications:
        return unreadNotifications;
      case NavBadgeKey.activeCrises:
        return activeCrises;
      case NavBadgeKey.suggestedMatches:
        return suggestedMatches;
      case NavBadgeKey.interactionRequests:
        return interactionRequests;
      case null:
        return 0;
    }
  }
}

Future<int> _safeCount(Future<int> Function() fn) async {
  try {
    return await fn();
  } catch (_) {
    return 0;
  }
}

Future<int> _countRows(String table, Map<String, Object> filters) async {
  var query = sb.from(table).select('id');
  filters.forEach((column, value) {
    query = query.eq(column, value);
  });
  final rows = await query;
  return (rows as List).length;
}

/// Ungelesene DMs – matched die Web-App: für jede conversation_members-Zeile
/// vergleichen wir last_read_at mit messages.created_at und zählen nur
/// Nachrichten, die nicht vom User selbst stammen.
Future<int> _countUnreadDms(String userId) async {
  final rows = await sb
      .from('conversation_members')
      .select('conversation_id, last_read_at, conversations!inner(type)')
      .eq('user_id', userId);

  if (rows is! List) return 0;

  var total = 0;
  for (final row in rows) {
    final convId = (row as Map<String, dynamic>)['conversation_id'] as String?;
    if (convId == null) continue;
    final conv = row['conversations'] as Map<String, dynamic>?;
    if (conv == null || conv['type'] == 'system') continue;
    final lastReadStr = row['last_read_at'] as String?;
    final lastRead = lastReadStr != null ? DateTime.tryParse(lastReadStr) : null;

    var msgQuery = sb
        .from('messages')
        .select('id')
        .eq('conversation_id', convId)
        .neq('sender_id', userId);
    if (lastRead != null) {
      msgQuery = msgQuery.gt('created_at', lastRead.toIso8601String());
    }
    final msgs = await msgQuery;
    if (msgs is List) total += msgs.length;
  }
  return total;
}

final badgeCountsProvider = StreamProvider<BadgeCounts>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield const BadgeCounts();
    return;
  }

  Future<BadgeCounts> fetchAll() async {
    final results = await Future.wait([
      _safeCount(() => _countUnreadDms(user.id)),
      _safeCount(() => _countRows('notifications', {'user_id': user.id, 'read': false})),
      _safeCount(() => _countRows('crisis_reports', {'status': 'active'})),
      _safeCount(() => _countRows('matches', {'user_id': user.id, 'viewed': false})),
      _safeCount(() => _countRows('interactions', {'recipient_id': user.id, 'status': 'pending'})),
    ]);

    return BadgeCounts(
      unreadMessages: results[0],
      unreadNotifications: results[1],
      activeCrises: results[2],
      suggestedMatches: results[3],
      interactionRequests: results[4],
    );
  }

  yield await fetchAll();
  await for (final _ in Stream<int>.periodic(const Duration(seconds: 30))) {
    yield await fetchAll();
  }
});
