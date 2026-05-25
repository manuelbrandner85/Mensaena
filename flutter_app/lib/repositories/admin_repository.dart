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
      count('crises'),
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
    String? statusFilter,
    String? search,
  }) async {
    try {
      var q = sb.from(table).select();
      if (statusFilter != null) q = q.eq('status', statusFilter);
      if (search != null && search.trim().isNotEmpty) {
        final esc = search.trim().replaceAll('%', r'\%');
        q = q.or('reason.ilike.%$esc%,title.ilike.%$esc%,name.ilike.%$esc%');
      }
      final rows = await q.order(orderBy, ascending: false).limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Generisches Status-Update fuer Moderation (z.B. Reports, Posts).
  static Future<bool> updateStatus({
    required String table,
    required String id,
    required String status,
  }) async {
    try {
      await sb.from(table).update({'status': status}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generisches Hard-Delete einer Row.
  static Future<bool> delete({
    required String table,
    required String id,
  }) async {
    try {
      await sb.from(table).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generisches Feld-Update (z.B. is_banned/is_admin auf profiles).
  static Future<bool> updateField({
    required String table,
    required String id,
    required String column,
    required dynamic value,
  }) async {
    try {
      await sb.from(table).update({column: value}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Users-Lookup via admin_list_users RPC. Liefert ALLE auth.users
  /// (auch unconfirmed + ohne Profile-Row). 1:1 zum Web Admin-UsersTab.
  /// Bei Fehler/keine Admin-Rolle → Fallback auf profiles-Lookup.
  static Future<List<Map<String, dynamic>>> listUsersViaRpc({
    String? search,
    bool onlyUnconfirmed = false,
    bool onlyMissingProfile = false,
    int limit = 100,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('admin_list_users', params: {
        'p_search': (search ?? '').isEmpty ? null : search,
        'p_only_unconfirmed': onlyUnconfirmed,
        'p_only_missing_profile': onlyMissingProfile,
        'p_limit': limit,
        'p_offset': 0,
      });
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (_) {
      // Fallback fuer den Fall dass Migration noch nicht angewendet wurde
      return recent('profiles', orderBy: 'created_at');
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
