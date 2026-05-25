/// SKILL: mensaena-features + supabase
/// Help-Streak-Service (F50): zaehlt aufeinanderfolgende Tage, an denen
/// der User mindestens 1 abgeschlossene Hilfe angeboten hat
/// (interactions.status = 'completed', helper_id = uid).
///
/// Liest direkt aus der echten Tabelle — kein lokales Caching ueber
/// _todaysHelp hinaus, weil completed_at die Wahrheit ist.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class HelpStreakData {
  const HelpStreakData({
    required this.current,
    required this.helpsToday,
    required this.lastHelpDate,
  });

  final int current;
  final int helpsToday;
  final DateTime? lastHelpDate;

  bool get helpedToday => helpsToday > 0;
}

class HelpStreakService {
  const HelpStreakService._();

  static Future<HelpStreakData> compute() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      return const HelpStreakData(
          current: 0, helpsToday: 0, lastHelpDate: null);
    }
    try {
      // Lade alle completed-Helps der letzten 90 Tage.
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 90))
          .toIso8601String();
      final rows = await sb
          .from('interactions')
          .select('completed_at')
          .eq('helper_id', uid)
          .eq('status', 'completed')
          .gte('completed_at', since)
          .order('completed_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        return const HelpStreakData(
            current: 0, helpsToday: 0, lastHelpDate: null);
      }
      // Set von einzigartigen Helping-Days (lokal).
      final daysSet = <String>{};
      DateTime? mostRecent;
      for (final r in list) {
        final raw = r['completed_at'] as String?;
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw)?.toLocal();
        if (dt == null) continue;
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        daysSet.add(key);
        mostRecent ??= dt;
      }
      final today = DateTime.now();
      final today0 = DateTime(today.year, today.month, today.day);
      final yesterday = today0.subtract(const Duration(days: 1));

      String dayKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final helpsToday = list.where((r) {
        final raw = r['completed_at'] as String?;
        if (raw == null) return false;
        final dt = DateTime.tryParse(raw)?.toLocal();
        if (dt == null) return false;
        return DateTime(dt.year, dt.month, dt.day) == today0;
      }).length;

      // Streak: zaehle von heute (oder gestern wenn heute noch nicht geholfen)
      // rueckwaerts, solange jeder Tag in daysSet ist.
      DateTime cursor;
      if (daysSet.contains(dayKey(today0))) {
        cursor = today0;
      } else if (daysSet.contains(dayKey(yesterday))) {
        cursor = yesterday;
      } else {
        return HelpStreakData(
            current: 0, helpsToday: 0, lastHelpDate: mostRecent);
      }
      int streak = 0;
      while (daysSet.contains(dayKey(cursor))) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return HelpStreakData(
        current: streak,
        helpsToday: helpsToday,
        lastHelpDate: mostRecent,
      );
    } catch (e) {
      debugPrint('[HelpStreak] compute failed: $e');
      return const HelpStreakData(
          current: 0, helpsToday: 0, lastHelpDate: null);
    }
  }
}
