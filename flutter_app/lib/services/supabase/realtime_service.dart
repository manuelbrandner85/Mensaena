import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Realtime-Channel-Helpers. Konsolidiert das Naming-Schema und sorgt
/// dafuer dass Channels beim dispose() sauber unsubscribed werden.
class RealtimeService {
  const RealtimeService();

  SupabaseClient get _c => supabase.client;

  /// Realtime auf eine Tabelle filtern via postgres_changes.
  RealtimeChannel onTable(
    String tableName, {
    required void Function(PostgresChangePayload payload) onChange,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    PostgresChangeFilter? filter,
  }) {
    final channel = _c.channel('public:$tableName:${DateTime.now().microsecondsSinceEpoch}');
    return channel
      ..onPostgresChanges(
        event: event,
        schema: 'public',
        table: tableName,
        filter: filter,
        callback: onChange,
      )
      ..subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _c.removeChannel(channel);
}

const realtime = RealtimeService();
