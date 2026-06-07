/// SKILL: mensaena-features (P12) — Offline-Queue.
/// Buffert Post-Inserts und Message-Sends wenn keine Verbindung besteht.
/// Bei Reconnect (`ConnectivityResult != none`) wird die Queue ausgespielt.
///
/// Retry-Härtung: Schlägt ein Insert beim Flush fehl (z.B. Supabase kurz
/// nicht erreichbar), bleibt das Item NICHT für immer stuck. Stattdessen
/// wird `retry_count` hochgezählt. Erst nach [_maxRetries] Versuchen wird
/// das Item verworfen, damit ein dauerhaft fehlerhafter Eintrag (z.B.
/// RLS-Verstoß) die ganze Queue nicht blockiert.
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

  /// Max. Flush-Versuche pro Item, bevor es verworfen wird.
  static const int _maxRetries = 3;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Verhindert parallele Flushes (z.B. Reconnect-Event + Initial-Check
  /// gleichzeitig) — sonst könnte dasselbe Item doppelt inserted werden.
  bool _flushing = false;

  Future<void> install() async {
    try {
      _sub = Connectivity().onConnectivityChanged.listen((res) {
        if (res.any((r) => r != ConnectivityResult.none)) {
          unawaited(flush().catchError((_) {}));
        }
      });
    } catch (_) {/* Connectivity-Listener konnte nicht registriert werden */}
    // Initial-Check NICHT awaiten — falls connectivity_plus auf dem Device
    // haengt (selten, aber moeglich), darf das nicht die App-Init blockieren.
    unawaited(
      Connectivity().checkConnectivity().then((res) {
        if (res.any((r) => r != ConnectivityResult.none)) {
          unawaited(flush().catchError((_) {}));
        }
      }).catchError((_) {}),
    );
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
      'retry_count': 0,
    });
    await _write(items);
  }

  Future<int> pendingCount() async => (await _read()).length;

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final items = await _read();
      if (items.isEmpty) return;
      final remaining = <Map<String, dynamic>>[];
      for (final item in items) {
        try {
          final table = item['table'] as String;
          final payload = (item['payload'] as Map).cast<String, dynamic>();
          await sb.from(table).insert(payload);
        } catch (_) {
          // Fehlgeschlagen → Retry-Zähler erhöhen. Items mit Bestandsschutz
          // (alte Queue ohne retry_count) starten bei 0.
          final tries = (item['retry_count'] as num?)?.toInt() ?? 0;
          if (tries + 1 < _maxRetries) {
            remaining.add({...item, 'retry_count': tries + 1});
          }
          // Bei Erreichen von _maxRetries: Item wird NICHT übernommen →
          // verworfen, damit ein Dauerfehler die Queue nicht blockiert.
        }
      }
      await _write(remaining);
    } finally {
      _flushing = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
