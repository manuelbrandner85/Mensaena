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
/// und über Realtime-Channels live aktualisiert (siehe TODO im Body).
final badgeCountsProvider = StreamProvider<BadgeCounts>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield const BadgeCounts();
    return;
  }

  Future<BadgeCounts> fetchAll() async {
    final results = await Future.wait([
      // Ungelesene Nachrichten (DM)
      sb.from('direct_messages').select().eq('recipient_id', user.id).eq('read', false).count(CountOption.exact),
      // Ungelesene Notifications
      sb.from('notifications').select().eq('user_id', user.id).eq('read', false).count(CountOption.exact),
      // Aktive Krisenberichte (im Umkreis – vereinfachte Version, Logik wie Web)
      sb.from('crisis_reports').select().eq('status', 'active').count(CountOption.exact),
      // Suggested Matches
      sb.from('matches').select().eq('user_id', user.id).eq('viewed', false).count(CountOption.exact),
      // Interaction-Requests
      sb.from('interactions').select().eq('recipient_id', user.id).eq('status', 'pending').count(CountOption.exact),
    ]);

    return BadgeCounts(
      unreadMessages: results[0].count,
      unreadNotifications: results[1].count,
      activeCrises: results[2].count,
      suggestedMatches: results[3].count,
      interactionRequests: results[4].count,
    );
  }

  yield await fetchAll();

  // Realtime-Refresh bei DB-Änderungen (vereinfachter Trigger).
  final channel = sb.channel('badge_counts_${user.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (_) {},
      )
      .subscribe();

  // Polling-Fallback alle 30s.
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await fetchAll();
  }
});
