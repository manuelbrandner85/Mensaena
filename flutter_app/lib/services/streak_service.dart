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

  /// Liest den aktuellen Streak. Aktualisiert nicht.
  static Future<StreakData> read() async {
    try {
      final current =
          int.tryParse(await _storage.read(key: _currentKey) ?? '') ?? 0;
      final best = int.tryParse(await _storage.read(key: _bestKey) ?? '') ?? 0;
      final lastRaw = await _storage.read(key: _lastDateKey);
      DateTime? last;
      if (lastRaw != null && lastRaw.isNotEmpty) {
        last = DateTime.tryParse(lastRaw);
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
