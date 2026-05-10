import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase.dart';

/// Lightweight Crash-Logger ohne externe SDKs (kein Sentry/Crashlytics).
/// Speichert Errors lokal in SharedPreferences und sendet sie beim
/// nächsten erfolgreichen App-Start in die `error_logs`-Tabelle.
///
/// Vorteile:
/// - Kein neues APK nötig (Dart-only, OTA-fähig)
/// - Funktioniert offline (Queue persistiert lokal)
/// - Daten bleiben in eigener Supabase-DB statt extern
class CrashLog {
  CrashLog._();

  static const _kQueue = 'crash_log.queue';
  static const _maxQueue = 50;

  /// Hängt einen Eintrag an die lokale Queue. Wird im nächsten Start
  /// automatisch geflusht (siehe `flushPending()`).
  static Future<void> capture({
    required String errorType,
    required Object error,
    StackTrace? stack,
    String? extraContext,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_kQueue) ?? const [];
      final entry = jsonEncode({
        'error_type': errorType,
        'message':
            error.toString().substring(0, error.toString().length.clamp(0, 4000)),
        'stack': stack?.toString().substring(
              0,
              stack.toString().length.clamp(0, 8000),
            ),
        'extra_context': extraContext,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      });
      final updated = [...queue, entry];
      // Limit verhindert unbegrenztes Wachsen wenn Flush nie klappt.
      final trimmed = updated.length > _maxQueue
          ? updated.sublist(updated.length - _maxQueue)
          : updated;
      await prefs.setStringList(_kQueue, trimmed);
    } catch (e, st) {
      // CrashLog selbst darf nicht crashen.
      debugPrint('CrashLog.capture failed: $e\n$st');
    }
  }

  /// Versucht alle gequeuten Errors an Supabase zu senden. Bei Fehler
  /// (z. B. Offline) bleibt die Queue erhalten und wird beim nächsten
  /// Start erneut versucht.
  static Future<void> flushPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_kQueue) ?? const [];
      if (queue.isEmpty) return;
      final user = sb.auth.currentUser;
      final rows = queue
          .map((s) {
            try {
              final m = jsonDecode(s) as Map<String, dynamic>;
              return <String, dynamic>{
                if (user != null) 'user_id': user.id,
                'platform': 'flutter',
                'error_type': m['error_type'],
                'message': m['message'],
                if (m['stack'] != null) 'stack': m['stack'],
                if (m['extra_context'] != null)
                  'device_info': m['extra_context'],
              };
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      if (rows.isEmpty) {
        await prefs.remove(_kQueue);
        return;
      }
      await sb.from('error_logs').insert(rows);
      await prefs.remove(_kQueue);
    } catch (e, st) {
      debugPrint('CrashLog.flushPending failed: $e\n$st');
    }
  }
}
