/// SKILL: mensaena-features
/// Screen-Time-Tracker: misst die heutige Verweildauer in der App und
/// triggert ein sanftes Detox-Reminder-Dialog wenn ein Threshold
/// ueberschritten wurde.
///
/// Persistierung pro Tag in flutter_secure_storage —
/// kein Backend, alles On-Device. User-Toggle in Settings →
/// Appearance-Tab.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScreenTimeService {
  const ScreenTimeService._();

  static const _storage = FlutterSecureStorage();
  static const _todayKey = 'mensaena_screentime_v1';
  static const _todayDateKey = 'mensaena_screentime_date_v1';
  static const _shownKey = 'mensaena_detox_shown_v1';
  static const _enabledKey = 'mensaena_detox_enabled_v1';
  static const _thresholdKey = 'mensaena_detox_threshold_min_v1';
  static const _defaultThresholdMin = 60;

  static DateTime? _sessionStart;

  // ── Konfiguration ────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    try {
      final raw = await _storage.read(key: _enabledKey);
      return raw != 'false'; // Default: an
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      await _storage.write(key: _enabledKey, value: v ? 'true' : 'false');
    } catch (_) {}
  }

  static Future<int> getThresholdMin() async {
    try {
      final raw = await _storage.read(key: _thresholdKey);
      return int.tryParse(raw ?? '') ?? _defaultThresholdMin;
    } catch (_) {
      return _defaultThresholdMin;
    }
  }

  static Future<void> setThresholdMin(int min) async {
    try {
      await _storage.write(key: _thresholdKey, value: '$min');
    } catch (_) {}
  }

  // ── Session-Tracking ─────────────────────────────────────────────

  /// Wird beim App-Resume (Foreground) aufgerufen.
  static void startSession() {
    _sessionStart = DateTime.now();
  }

  /// Wird beim App-Pause (Background) aufgerufen.
  /// Berechnet Session-Dauer + addiert sie zum heutigen Total.
  static Future<void> endSession() async {
    final start = _sessionStart;
    if (start == null) return;
    _sessionStart = null;
    final dur = DateTime.now().difference(start);
    if (dur.inSeconds < 5) return; // Mini-Sessions ignorieren
    await _addToToday(dur);
  }

  static Future<void> _addToToday(Duration dur) async {
    try {
      final today = _dateString(DateTime.now());
      final cachedDate = await _storage.read(key: _todayDateKey);
      int totalSec = 0;
      if (cachedDate == today) {
        totalSec = int.tryParse(
                await _storage.read(key: _todayKey) ?? '0') ??
            0;
      } else {
        // Neuer Tag → Reset
        await _storage.write(key: _shownKey, value: 'false');
        await _storage.write(key: _todayDateKey, value: today);
      }
      totalSec += dur.inSeconds;
      await _storage.write(key: _todayKey, value: '$totalSec');
    } catch (e) {
      debugPrint('[ScreenTime] addToToday failed: $e');
    }
  }

  // ── Reminder-Logik ───────────────────────────────────────────────

  /// Heute schon X Minuten in der App?
  static Future<int> getTodayMinutes() async {
    try {
      final today = _dateString(DateTime.now());
      final cachedDate = await _storage.read(key: _todayDateKey);
      if (cachedDate != today) return 0;
      final sec = int.tryParse(
              await _storage.read(key: _todayKey) ?? '0') ??
          0;
      // Plus laufende Session (falls aktiv)
      final running = _sessionStart != null
          ? DateTime.now().difference(_sessionStart!).inSeconds
          : 0;
      return ((sec + running) / 60).floor();
    } catch (_) {
      return 0;
    }
  }

  /// True wenn (1) Feature an, (2) Threshold heute erreicht, (3) Dialog
  /// heute noch nicht gezeigt.
  static Future<bool> shouldRemind() async {
    if (!await isEnabled()) return false;
    final threshold = await getThresholdMin();
    final today = await getTodayMinutes();
    if (today < threshold) return false;
    try {
      final shown = await _storage.read(key: _shownKey);
      return shown != 'true';
    } catch (_) {
      return false;
    }
  }

  /// Markiert: heute schon einmal gezeigt — kein zweites Dialog pro Tag.
  static Future<void> markRemindedToday() async {
    try {
      await _storage.write(key: _shownKey, value: 'true');
    } catch (_) {}
  }

  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
