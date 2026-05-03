import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import 'nav_config.dart';

/// Provider für Badge-Counts in der Navigation. 1:1-Pendant zur Web-App,
/// wo widgetStore die Zähler hält und Realtime-Subscriptions sie aktualisieren.
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

/// Lädt die Counts aus Supabase. Wird beim App-Start einmal geladen
/// und alle 30s neu gepollt; ein Realtime-Refresh kommt im nächsten Schritt
/// (analog zur Web-App, die `widgetStore` über Supabase-Channels aktualisiert).
final badgeCountsProvider = StreamProvider<BadgeCounts>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield const BadgeCounts();
    return;
  }

  Future<int> _count(String table, Map<String, Object> filters) async {
    var query = sb.from(table).select('id');
    filters.forEach((column, value) {
      query = query.eq(column, value);
    });
    final rows = await query;
    return (rows as List).length;
  }

  Future<BadgeCounts> fetchAll() async {
    final results = await Future.wait([
      _count('direct_messages', {'recipient_id': user.id, 'read': false}),
      _count('notifications', {'user_id': user.id, 'read': false}),
      _count('crisis_reports', {'status': 'active'}),
      _count('matches', {'user_id': user.id, 'viewed': false}),
      _count('interactions', {'recipient_id': user.id, 'status': 'pending'}),
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

  // Polling-Fallback alle 30s. Realtime-Subscription (Pendant zu
  // supabase.channel().on('postgres_changes', …) im Web) wird in einem
  // Folge-Commit ergänzt, sobald die genaue Tabellen-Liste feststeht.
  await for (final _ in Stream<int>.periodic(const Duration(seconds: 30))) {
    yield await fetchAll();
  }
});
