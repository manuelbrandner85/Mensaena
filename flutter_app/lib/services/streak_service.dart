/// SKILL: mensaena-features
/// Streak-Service: zaehlt aufeinanderfolgende Tage, an denen der User die
/// App geoeffnet hat. Persistiert on-device in flutter_secure_storage.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StreakData {
  const StreakData({
    required this.current,
    required this.best,
    required this.lastOpenDate,
  });

  final int current;
  final int best;
  final DateTime? lastOpenDate;

  bool get openedToday {
    final last = lastOpenDate;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }
}

class StreakService {
  const StreakService._();

  static const _storage = FlutterSecureStorage();
  static const _currentKey = 'mensaena_streak_current_v1';
  static const _bestKey = 'mensaena_streak_best_v1';
  static const _lastDateKey = 'mensaena_streak_last_date_v1';
  // F50: Streak-Freeze. Speichert die ISO-Wochen-Nummer in der der
  // letzte Freeze eingesetzt wurde — 1 pro Kalenderwoche.
  static const _freezeWeekKey = 'mensaena_streak_freeze_week_v1';

  /// ISO-Week-Identifier wie "2026-W21". Stable über Year-Boundaries.
  static String _isoWeekKey(DateTime d) {
    // Donnerstag derselben Woche → ISO-Year-Anker
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final yearStart = DateTime(thursday.year, 1, 1);
    final firstThursday = yearStart.add(Duration(
        days: (4 - yearStart.weekday + 7) % 7));
    final weekNum =
        ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// `true` wenn diese Woche noch ein Freeze verfügbar ist.
  static Future<bool> isFreezeAvailable() async {
    try {
      final raw = await _storage.read(key: _freezeWeekKey);
      if (raw == null || raw.isEmpty) return true;
      return raw != _isoWeekKey(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  /// Setzt den Freeze ein: tut so als ob heute schon geöffnet wäre
  /// (sodass morgen der Streak normal weiterlaufen kann ohne dass die
  /// heutige Lücke zählt). Returns `true` wenn erfolgreich gesetzt,
  /// `false` wenn diese Woche bereits ein Freeze verwendet wurde.
  static Future<bool> useFreeze() async {
    try {
      final week = _isoWeekKey(DateTime.now());
      final raw = await _storage.read(key: _freezeWeekKey);
      if (raw == week) return false; // schon verbraucht
      final today = DateTime.now();
      final pinned = DateTime(today.year, today.month, today.day);
      await _storage.write(
          key: _lastDateKey, value: pinned.toIso8601String());
      await _storage.write(key: _freezeWeekKey, value: week);
      return true;
    } catch (e) {
      debugPrint('[Streak] useFreeze failed: $e');
      return false;
    }
  }

  /// Liest den aktuellen Streak. Aktualisiert nicht.
  static Future<StreakData> read() async {
    try {
      final current =
          int.tryParse(await _storage.read(key: _currentKey) ?? '') ?? 0;
      final best = int.tryParse(await _storage.read(key: _bestKey) ?? '') ?? 0;
      final lastRaw = await _storage.read(key: _lastDateKey);
      DateTime? last;
      if (lastRaw != null && lastRaw.isNotEmpty) {
        last = DateTime.tryParse(lastRaw)?.toUtc();
      }
      return StreakData(current: current, best: best, lastOpenDate: last);
    } catch (_) {
      return const StreakData(current: 0, best: 0, lastOpenDate: null);
    }
  }

  /// Bei App-Open aufrufen. Aktualisiert Streak nach Tages-Logik:
  /// - Gleicher Tag wie letzter Open → keine Aenderung.
  /// - Genau 1 Tag spaeter → current++.
  /// - Mehr als 1 Tag Luecke → current = 1.
  /// - Erster Open ueberhaupt → current = 1.
  static Future<StreakData> recordOpen() async {
    try {
      final data = await read();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int next = data.current;
      final last = data.lastOpenDate;

      if (last == null) {
        next = 1;
      } else {
        final lastDay = DateTime(last.year, last.month, last.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 0) {
          // schon heute geoeffnet → kein Update
          return data;
        } else if (diff == 1) {
          next = data.current + 1;
        } else {
          next = 1;
        }
      }

      final best = next > data.best ? next : data.best;

      await _storage.write(key: _currentKey, value: '$next');
      await _storage.write(key: _bestKey, value: '$best');
      await _storage.write(key: _lastDateKey, value: today.toIso8601String());

      return StreakData(current: next, best: best, lastOpenDate: today);
    } catch (e) {
      debugPrint('[Streak] recordOpen failed: $e');
      return read();
    }
  }
}
