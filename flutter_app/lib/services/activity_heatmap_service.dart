/// SKILL: mensaena-features + supabase
/// Activity-Heatmap-Service (F33): zaehlt pro Tag der letzten 84 Tage
/// die Aktivitaet des Users (Posts + Kommentare + abgeschlossene Hilfen).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class ActivityHeatmap {
  const ActivityHeatmap({required this.days});

  /// Map von Datum (YYYY-MM-DD) → Aktivitaets-Count.
  /// Enthaelt nur Tage mit > 0 Aktivitaet.
  final Map<String, int> days;

  int countFor(DateTime d) =>
      days['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] ??
      0;

  int get maxCount {
    if (days.isEmpty) return 0;
    return days.values.reduce((a, b) => a > b ? a : b);
  }

  int get totalCount {
    if (days.isEmpty) return 0;
    return days.values.reduce((a, b) => a + b);
  }
}

class ActivityHeatmapService {
  const ActivityHeatmapService._();

  static const _days = 84; // 12 Wochen

  static Future<ActivityHeatmap> compute({String? userId}) async {
    final uid = userId ?? SupabaseService.currentUser?.id;
    if (uid == null) return const ActivityHeatmap(days: {});
    final since =
        DateTime.now().toUtc().subtract(const Duration(days: _days));
    final sinceIso = since.toIso8601String();
    final counts = <String, int>{};

    Future<void> addFrom({
      required String table,
      required String userCol,
      required String tsCol,
      Map<String, Object> extra = const {},
    }) async {
      try {
        var q =
            sb.from(table).select(tsCol).eq(userCol, uid).gte(tsCol, sinceIso);
        for (final e in extra.entries) {
          q = q.eq(e.key, e.value);
        }
        final rows = await q;
        for (final r in rows as List) {
          final ts = (r as Map)[tsCol] as String?;
          if (ts == null) continue;
          final dt = DateTime.tryParse(ts)?.toUtc();
          if (dt == null) continue;
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
      } catch (e) {
        debugPrint('[ActivityHeatmap] $table query failed: $e');
      }
    }

    await Future.wait([
      addFrom(table: 'posts', userCol: 'user_id', tsCol: 'created_at'),
      addFrom(
          table: 'post_comments', userCol: 'user_id', tsCol: 'created_at'),
      addFrom(
        table: 'interactions',
        userCol: 'helper_id',
        tsCol: 'completed_at',
        extra: const {'status': 'completed'},
      ),
    ]);

    return ActivityHeatmap(days: counts);
  }
}
