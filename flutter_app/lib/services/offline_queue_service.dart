/// SKILL: mensaena-features (P12) — Offline-Queue.
/// Buffert Post-Inserts und Message-Sends wenn keine Verbindung besteht.
/// Bei Reconnect (`ConnectivityResult != none`) wird die Queue ausgespielt.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_service.dart';

class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mensaena_offline_queue_v1';

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> install() async {
    _sub = Connectivity().onConnectivityChanged.listen((res) {
      if (res.any((r) => r != ConnectivityResult.none)) {
        unawaited(flush());
      }
    });
    final initial = await Connectivity().checkConnectivity();
    if (initial.any((r) => r != ConnectivityResult.none)) {
      unawaited(flush());
    }
  }

  Future<List<Map<String, dynamic>>> _read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(items));
    } catch (_) {}
  }

  Future<void> enqueue({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final items = await _read();
    items.add({
      'table': table,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _write(items);
  }

  Future<int> pendingCount() async => (await _read()).length;

  Future<void> flush() async {
    final items = await _read();
    if (items.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final item in items) {
      try {
        final table = item['table'] as String;
        final payload = (item['payload'] as Map).cast<String, dynamic>();
        await sb.from(table).insert(payload);
      } catch (_) {
        remaining.add(item);
      }
    }
    await _write(remaining);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
