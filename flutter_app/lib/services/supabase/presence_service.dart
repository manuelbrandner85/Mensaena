import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Presence via Supabase Realtime — Pendant zum user_status-System der
/// Web-App. Tracks "Online" / "Verfuegbar" / "Offline" auf einem Channel
/// statt einer Tabelle (skaliert besser fuer hohen Live-Traffic).
class PresenceService {
  PresenceService();

  RealtimeChannel? _channel;
  final SupabaseClient _c = supabase.client;

  /// Tritt dem globalen Presence-Channel bei und synct den eigenen
  /// Status. Liefert einen Stream der aktuellen Online-Userset-Snapshots.
  Stream<Set<String>> join(String userId, {String status = 'online'}) async* {
    _channel = _c.channel('global-presence', opts: const RealtimeChannelConfig(self: true));
    final controller = _PresenceController();

    _channel!.onPresenceSync((payload) {
      final state = _channel!.presenceState();
      final ids = <String>{};
      for (final entry in state) {
        for (final p in entry.presences) {
          final id = p.payload['user_id'];
          if (id is String) ids.add(id);
        }
      }
      controller.emit(ids);
    });

    _channel!.subscribe((state, [error]) async {
      if (state == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({'user_id': userId, 'status': status, 'online_at': DateTime.now().toIso8601String()});
      }
    });

    await for (final s in controller.stream) {
      yield s;
    }
  }

  Future<void> leave() async {
    if (_channel == null) return;
    await _channel!.untrack();
    await _c.removeChannel(_channel!);
    _channel = null;
  }
}

class _PresenceController {
  Set<String>? _last;
  final List<void Function(Set<String>)> _listeners = [];

  void emit(Set<String> set) {
    _last = set;
    for (final l in _listeners) {
      l(set);
    }
  }

  Stream<Set<String>> get stream async* {
    if (_last != null) yield _last!;
    final pending = <Set<String>>[];
    _listeners.add(pending.add);
    while (true) {
      if (pending.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      yield pending.removeAt(0);
    }
  }
}
