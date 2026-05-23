import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Globale Online-Presence — Pendant zu Web `usePresence` Hook.
/// Channel "online_users" trackt alle eingeloggten User. Liefert per
/// [onlineUsersProvider] Set der online User-IDs.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  RealtimeChannel? _channel;
  final Set<String> _online = {};
  final List<void Function(Set<String>)> _listeners = [];

  void addListener(void Function(Set<String>) cb) {
    _listeners.add(cb);
    cb(Set.from(_online));
  }

  void removeListener(void Function(Set<String>) cb) {
    _listeners.remove(cb);
  }

  void _emit() {
    for (final l in _listeners) {
      l(Set.from(_online));
    }
  }

  Future<void> start() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || _channel != null) return;
    _channel = sb.channel(
      'online_users',
      opts: const RealtimeChannelConfig(self: true),
    );
    _channel!.onPresenceSync((_) {
      _online
        ..clear()
        ..addAll(
          _channel!
              .presenceState()
              .expand((p) => p.presences)
              .map((p) => (p.payload['user_id'] as String?) ?? '')
              .where((s) => s.isNotEmpty),
        );
      _emit();
    });
    _channel!.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _channel!.track({
          'user_id': uid,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
    _online.clear();
    _emit();
  }

  bool isOnline(String userId) => _online.contains(userId);
}

/// Riverpod-Provider, der ein Stream<Set<String>> der online User-IDs liefert.
final onlineUsersProvider = StreamProvider<Set<String>>((ref) async* {
  await PresenceService.instance.start();
  final controller = StreamController<Set<String>>();
  void cb(Set<String> ids) => controller.add(ids);
  PresenceService.instance.addListener(cb);
  ref.onDispose(() {
    PresenceService.instance.removeListener(cb);
    controller.close();
  });
  yield* controller.stream;
});
