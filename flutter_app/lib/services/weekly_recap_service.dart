/// SKILL: mensaena-features + supabase
/// Weekly-Recap-Service (F40): aggregiert eigene Aktivitaet der aktuellen
/// und letzten 7-Tage-Periode. Liefert Delta-Werte fuer den Wochenrueckblick.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class WeeklyRecap {
  const WeeklyRecap({
    required this.helpsThisWeek,
    required this.helpsLastWeek,
    required this.postsThisWeek,
    required this.postsLastWeek,
    required this.commentsThisWeek,
    required this.commentsLastWeek,
  });

  final int helpsThisWeek;
  final int helpsLastWeek;
  final int postsThisWeek;
  final int postsLastWeek;
  final int commentsThisWeek;
  final int commentsLastWeek;

  int get totalThisWeek => helpsThisWeek + postsThisWeek + commentsThisWeek;
  int get totalLastWeek => helpsLastWeek + postsLastWeek + commentsLastWeek;

  /// In Prozent. + = gestiegen, - = gefallen, 0 = gleich.
  int get totalDeltaPct {
    if (totalLastWeek == 0) {
      return totalThisWeek > 0 ? 100 : 0;
    }
    return (((totalThisWeek - totalLastWeek) / totalLastWeek) * 100).round();
  }
}

class WeeklyRecapService {
  const WeeklyRecapService._();

  static Future<WeeklyRecap> compute() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      return const WeeklyRecap(
        helpsThisWeek: 0,
        helpsLastWeek: 0,
        postsThisWeek: 0,
        postsLastWeek: 0,
        commentsThisWeek: 0,
        commentsLastWeek: 0,
      );
    }
    final now = DateTime.now().toUtc();
    final thisWeekStart =
        now.subtract(const Duration(days: 7)).toIso8601String();
    final lastWeekStart =
        now.subtract(const Duration(days: 14)).toIso8601String();
    final lastWeekEnd = thisWeekStart;

    Future<int> count({
      required String table,
      required String userCol,
      required String tsCol,
      required String from,
      required String? to,
      Map<String, Object> extra = const {},
    }) async {
      try {
        var q = sb.from(table).select('id').eq(userCol, uid).gte(tsCol, from);
        if (to != null) q = q.lt(tsCol, to);
        for (final e in extra.entries) {
          q = q.eq(e.key, e.value);
        }
        final rows = await q;
        return (rows as List).length;
      } catch (e) {
        debugPrint('[WeeklyRecap] $table query failed: $e');
        return 0;
      }
    }

    final results = await Future.wait([
      count(
        table: 'interactions',
        userCol: 'helper_id',
        tsCol: 'completed_at',
        from: thisWeekStart,
        to: null,
        extra: const {'status': 'completed'},
      ),
      count(
        table: 'interactions',
        userCol: 'helper_id',
        tsCol: 'completed_at',
        from: lastWeekStart,
        to: lastWeekEnd,
        extra: const {'status': 'completed'},
      ),
      count(
        table: 'posts',
        userCol: 'user_id',
        tsCol: 'created_at',
        from: thisWeekStart,
        to: null,
      ),
      count(
        table: 'posts',
        userCol: 'user_id',
        tsCol: 'created_at',
        from: lastWeekStart,
        to: lastWeekEnd,
      ),
      count(
        table: 'post_comments',
        userCol: 'user_id',
        tsCol: 'created_at',
        from: thisWeekStart,
        to: null,
      ),
      count(
        table: 'post_comments',
        userCol: 'user_id',
        tsCol: 'created_at',
        from: lastWeekStart,
        to: lastWeekEnd,
      ),
    ]);

    return WeeklyRecap(
      helpsThisWeek: results[0],
      helpsLastWeek: results[1],
      postsThisWeek: results[2],
      postsLastWeek: results[3],
      commentsThisWeek: results[4],
      commentsLastWeek: results[5],
    );
  }
}
