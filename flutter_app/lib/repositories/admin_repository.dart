import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Admin-Repository — Counts + generische Tabellen-Liste.
class AdminRepository {
  const AdminRepository._();

  /// Zaehlt Rows einer Tabelle (best-effort, fallback 0).
  static Future<int> count(String table) async {
    try {
      final rows = await sb.from(table).select('id').limit(2000);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<AdminStats> stats() async {
    final results = await Future.wait([
      count('profiles'),
      count('posts'),
      count('events'),
      count('board_posts'),
      count('crisis_situations'),
      count('organizations'),
      count('farm_listings'),
      count('content_reports'),
    ]);
    return AdminStats(
      users: results[0],
      posts: results[1],
      events: results[2],
      boardPosts: results[3],
      crises: results[4],
      organizations: results[5],
      farms: results[6],
      reports: results[7],
    );
  }

  /// Letzte 100 Eintraege einer Tabelle mit beliebiger Sortspalte.
  static Future<List<Map<String, dynamic>>> recent(
    String table, {
    String orderBy = 'created_at',
  }) async {
    try {
      final rows = await sb
          .from(table)
          .select()
          .order(orderBy, ascending: false)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

class AdminStats {
  const AdminStats({
    required this.users,
    required this.posts,
    required this.events,
    required this.boardPosts,
    required this.crises,
    required this.organizations,
    required this.farms,
    required this.reports,
  });

  final int users;
  final int posts;
  final int events;
  final int boardPosts;
  final int crises;
  final int organizations;
  final int farms;
  final int reports;
}

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  return AdminRepository.stats();
});
