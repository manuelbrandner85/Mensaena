/// SKILL: mensaena-features + supabase
/// Personal-Best-Service (F46): aggregiert User-Lifetime-Spitzenwerte
/// fuer den Personal-Best-Widget.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'streak_service.dart';
import 'supabase_service.dart';

class PersonalBest {
  const PersonalBest({
    required this.totalHelps,
    required this.totalPosts,
    required this.totalComments,
    required this.bestLoginStreak,
    required this.bestSingleDayActions,
  });

  final int totalHelps;
  final int totalPosts;
  final int totalComments;
  final int bestLoginStreak;
  final int bestSingleDayActions;
}

class PersonalBestService {
  const PersonalBestService._();

  static const _storage = FlutterSecureStorage();
  static const _bestDayKey = 'mensaena_personal_best_day_v1';

  static Future<int> _getStoredBestDay() async {
    try {
      final raw = await _storage.read(key: _bestDayKey);
      return int.tryParse(raw ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _updateBestDay(int v) async {
    try {
      await _storage.write(key: _bestDayKey, value: '$v');
    } catch (_) {}
  }

  static Future<PersonalBest> compute() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      return const PersonalBest(
        totalHelps: 0,
        totalPosts: 0,
        totalComments: 0,
        bestLoginStreak: 0,
        bestSingleDayActions: 0,
      );
    }

    int helps = 0;
    int posts = 0;
    int comments = 0;
    final dayCounts = <String, int>{};

    Future<List<Map<String, dynamic>>> safe(
        Future<dynamic> Function() q) async {
      try {
        final r = await q();
        return (r as List).cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('[PersonalBest] query failed: $e');
        return const [];
      }
    }

    void bump(String? ts) {
      if (ts == null) return;
      final dt = DateTime.tryParse(ts)?.toLocal();
      if (dt == null) return;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }

    final helpsRows = await safe(() => sb
        .from('interactions')
        .select('completed_at')
        .eq('helper_id', uid)
        .eq('status', 'completed'));
    helps = helpsRows.length;
    for (final r in helpsRows) {
      bump(r['completed_at'] as String?);
    }

    final postsRows = await safe(
        () => sb.from('posts').select('created_at').eq('user_id', uid));
    posts = postsRows.length;
    for (final r in postsRows) {
      bump(r['created_at'] as String?);
    }

    final cmtRows = await safe(() =>
        sb.from('post_comments').select('created_at').eq('user_id', uid));
    comments = cmtRows.length;
    for (final r in cmtRows) {
      bump(r['created_at'] as String?);
    }

    int bestDay = 0;
    if (dayCounts.isNotEmpty) {
      bestDay = dayCounts.values.reduce((a, b) => a > b ? a : b);
    }
    final storedBest = await _getStoredBestDay();
    if (bestDay > storedBest) {
      await _updateBestDay(bestDay);
    } else if (storedBest > bestDay) {
      // Fallback wenn DB Eintraege geloescht wurden — wir bewahren den Wert.
      bestDay = storedBest;
    }

    final streak = await StreakService.read();

    return PersonalBest(
      totalHelps: helps,
      totalPosts: posts,
      totalComments: comments,
      bestLoginStreak: streak.best,
      bestSingleDayActions: bestDay,
    );
  }
}
