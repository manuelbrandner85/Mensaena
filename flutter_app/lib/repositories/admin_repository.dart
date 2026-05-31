import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show CountOption, PostgrestResponse;

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
    // Live-Erweiterung (client-seitig, ohne RPC-Änderung): Granulare
    // User-Metriken (24h/7d aktiv, neu 24h/30d, Rollen-Verteilung, gebannt).
    // Parallel zur Haupt-RPC, damit der Dashboard-Refresh nicht langsamer
    // wird. Bei Fehler werden 0-Werte zurückgegeben.
    Future<int> safeCount(Future<PostgrestResponse<dynamic>> Function() run) async {
      try {
        return (await run()).count;
      } catch (_) {
        return 0;
      }
    }

    Future<_UsersOverview> usersOverview() async {
      final results = await Future.wait<int>([
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .gte('updated_at', _ago(const Duration(hours: 24)))
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .gte('updated_at', _ago(const Duration(days: 7)))
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .gte('created_at', _ago(const Duration(hours: 24)))
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .gte('created_at', _ago(const Duration(days: 30)))
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .eq('role', 'admin')
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .eq('role', 'moderator')
            .count(CountOption.exact)),
        safeCount(() => sb
            .from('profiles')
            .select('id')
            .eq('is_banned', true)
            .count(CountOption.exact)),
      ]);
      return _UsersOverview(
        active24h: results[0],
        active7d: results[1],
        newUsers24h: results[2],
        newUsers30d: results[3],
        admins: results[4],
        moderators: results[5],
        bannedUsers: results[6],
      );
    }

    final overviewFuture = usersOverview();

    // Phase 1: try aggregated RPC for performance.
    try {
      final res = await sb.rpc<dynamic>('get_admin_dashboard_stats');
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        int i(String k) {
          final v = m[k];
          if (v is int) return v;
          if (v is num) return v.toInt();
          if (v is String) return int.tryParse(v) ?? 0;
          return 0;
        }

        double d(String k) {
          final v = m[k];
          if (v is double) return v;
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0.0;
          return 0.0;
        }

        // BUGFIX: Die RPC liefert Schlüssel im Format `total_*`/`active_*`,
        // der Dart-Code las aber zuvor die kurzen Aliase (`users`, `posts`,
        // …) — Resultat: ALLE Headline-Zahlen im Dashboard waren 0, obwohl
        // die DB 49 Nutzer:innen kennt. Erst-Schlüssel = RPC-Realität,
        // Zweit-Schlüssel = alter Alias als Sicherheitsnetz.
        int pick(String primary, String fallback) {
          final p = i(primary);
          return p != 0 ? p : i(fallback);
        }

        final overview = await overviewFuture;
        return AdminStats(
          users: pick('total_users', 'users'),
          posts: pick('total_posts', 'posts'),
          events: pick('total_events', 'events'),
          boardPosts: pick('total_board_posts', 'board_posts'),
          crises: pick('total_crises', 'crises'),
          organizations: pick('total_organizations', 'organizations'),
          farms: pick('total_farm_listings', 'farms'),
          reports: i('open_reports'),
          activeUsers30d: i('active_users_30d'),
          newUsers7d: i('new_users_7d'),
          newPosts7d: i('new_posts_7d'),
          activePosts: i('active_posts'),
          totalMessages: i('total_messages'),
          totalConversations: i('total_conversations'),
          upcomingEvents: i('upcoming_events'),
          activeBoardPosts: i('active_board_posts'),
          activeCrises: i('active_crises'),
          verifiedOrganizations: i('verified_organizations'),
          verifiedFarms: i('verified_farms'),
          totalTrustRatings: i('total_trust_ratings'),
          avgTrustScore: d('avg_trust_score'),
          totalGroups: i('total_groups'),
          activeGroups: i('active_groups'),
          totalChallenges: i('total_challenges'),
          activeChallenges: i('active_challenges'),
          totalTimebankHours: d('total_timebank_hours'),
          totalTimebankEntries: i('total_timebank_entries'),
          totalNotifications: i('total_notifications'),
          unreadNotifications: i('unread_notifications'),
          totalSavedPosts: i('total_saved_posts'),
          openReports: i('open_reports'),
          activeUsers24h: overview.active24h,
          activeUsers7d: overview.active7d,
          newUsers24h: overview.newUsers24h,
          newUsers30d: overview.newUsers30d,
          admins: overview.admins,
          moderators: overview.moderators,
          bannedUsers: overview.bannedUsers,
        );
      }
    } catch (_) {
      // fall-through to count-based fallback
    }

    // Phase 2: defensive count-based fallback.
    final base = await Future.wait([
      count('profiles'),
      count('posts'),
      count('events'),
      count('board_posts'),
      count('crises'),
      count('organizations'),
      count('farm_listings'),
      count('reports'),
      count('messages'),
      count('conversations'),
      count('groups'),
      count('challenges'),
      count('timebank_entries'),
      count('notifications'),
      count('saved_posts'),
      count('trust_ratings'),
    ]);

    int verifiedOrganizations = 0;
    try {
      final rows =
          await sb.from('organizations').select('id').eq('is_verified', true);
      verifiedOrganizations = (rows as List).length;
    } catch (_) {}

    int verifiedFarms = 0;
    try {
      final rows =
          await sb.from('farm_listings').select('id').eq('is_verified', true);
      verifiedFarms = (rows as List).length;
    } catch (_) {}

    int upcomingEvents = 0;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows =
          await sb.from('events').select('id').gte('start_date', now);
      upcomingEvents = (rows as List).length;
    } catch (_) {}

    int activeBoardPosts = 0;
    try {
      final rows =
          await sb.from('board_posts').select('id').eq('status', 'active');
      activeBoardPosts = (rows as List).length;
    } catch (_) {}

    int activeCrises = 0;
    try {
      final rows = await sb.from('crises').select('id').eq('status', 'active');
      activeCrises = (rows as List).length;
    } catch (_) {}

    int activePosts = 0;
    try {
      final rows = await sb.from('posts').select('id').eq('status', 'active');
      activePosts = (rows as List).length;
    } catch (_) {}

    int activeChallenges = 0;
    try {
      final rows =
          await sb.from('challenges').select('id').eq('status', 'active');
      activeChallenges = (rows as List).length;
    } catch (_) {}

    int activeGroups = 0;
    try {
      // BUGFIX: DB hat kein is_active — Schema nutzt is_archived. Eine
      // 'aktive' Gruppe ist eine die NICHT archiviert ist.
      final rows = await sb
          .from('groups')
          .select('id')
          .eq('is_archived', false);
      activeGroups = (rows as List).length;
    } catch (_) {}

    int openReports = 0;
    try {
      final rows =
          await sb.from('reports').select('id').eq('status', 'pending');
      openReports = (rows as List).length;
    } catch (_) {}

    int newUsers7d = 0;
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final rows = await sb.from('profiles').select('id').gte('created_at', since);
      newUsers7d = (rows as List).length;
    } catch (_) {}

    int newPosts7d = 0;
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final rows = await sb.from('posts').select('id').gte('created_at', since);
      newPosts7d = (rows as List).length;
    } catch (_) {}

    int activeUsers30d = 0;
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();
      final rows =
          await sb.from('profiles').select('id').gte('last_seen_at', since);
      activeUsers30d = (rows as List).length;
    } catch (_) {}

    int unreadNotifications = 0;
    try {
      final rows =
          await sb.from('notifications').select('id').eq('is_read', false);
      unreadNotifications = (rows as List).length;
    } catch (_) {}

    double avgTrustScore = 0.0;
    try {
      final rows = await sb.from('trust_ratings').select('score').limit(2000);
      final list = (rows as List).whereType<Map<String, dynamic>>().toList();
      if (list.isNotEmpty) {
        double sum = 0;
        int n = 0;
        for (final r in list) {
          final v = r['score'];
          if (v is num) {
            sum += v.toDouble();
            n++;
          }
        }
        if (n > 0) avgTrustScore = sum / n;
      }
    } catch (_) {}

    double totalTimebankHours = 0.0;
    try {
      final rows = await sb.from('timebank_entries').select('hours').limit(2000);
      final list = (rows as List).whereType<Map<String, dynamic>>().toList();
      for (final r in list) {
        final v = r['hours'];
        if (v is num) totalTimebankHours += v.toDouble();
      }
    } catch (_) {}

    final overview = await overviewFuture;
    return AdminStats(
      users: base[0],
      posts: base[1],
      events: base[2],
      boardPosts: base[3],
      crises: base[4],
      organizations: base[5],
      farms: base[6],
      reports: base[7],
      totalMessages: base[8],
      totalConversations: base[9],
      totalGroups: base[10],
      totalChallenges: base[11],
      totalTimebankEntries: base[12],
      totalNotifications: base[13],
      totalSavedPosts: base[14],
      totalTrustRatings: base[15],
      activeUsers30d: activeUsers30d,
      newUsers7d: newUsers7d,
      newPosts7d: newPosts7d,
      activePosts: activePosts,
      upcomingEvents: upcomingEvents,
      activeBoardPosts: activeBoardPosts,
      activeCrises: activeCrises,
      verifiedOrganizations: verifiedOrganizations,
      verifiedFarms: verifiedFarms,
      avgTrustScore: avgTrustScore,
      activeGroups: activeGroups,
      activeChallenges: activeChallenges,
      totalTimebankHours: totalTimebankHours,
      unreadNotifications: unreadNotifications,
      openReports: openReports,
      activeUsers24h: overview.active24h,
      activeUsers7d: overview.active7d,
      newUsers24h: overview.newUsers24h,
      newUsers30d: overview.newUsers30d,
      admins: overview.admins,
      moderators: overview.moderators,
      bannedUsers: overview.bannedUsers,
    );
  }

  static String _ago(Duration d) =>
      DateTime.now().subtract(d).toUtc().toIso8601String();

  /// Letzte N Eintraege einer Tabelle mit beliebiger Sortspalte.
  /// Default 500 — vorher 100, was bei kleinen Sub-Tabellen wie
  /// challenges/groups/contact_messages/bot_feedback regelmäßig nicht
  /// alle Zeilen zeigte.
  static Future<List<Map<String, dynamic>>> recent(
    String table, {
    String orderBy = 'created_at',
    String? statusFilter,
    String? search,
    int limit = 500,
  }) async {
    try {
      var q = sb.from(table).select();
      if (statusFilter != null) q = q.eq('status', statusFilter);
      if (search != null && search.trim().isNotEmpty) {
        final esc = search.trim().replaceAll('%', r'\%');
        q = q.or('reason.ilike.%$esc%,title.ilike.%$esc%,name.ilike.%$esc%');
      }
      final rows = await q.order(orderBy, ascending: false).limit(limit);
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
      unawaited(_logAdminAction(
        'admin_update_status',
        targetId: id,
        tableName: table,
        details: {'table': table, 'status': status},
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generisches Hard-Delete einer Row. Schreibt audit_logs.
  static Future<bool> delete({
    required String table,
    required String id,
  }) async {
    try {
      await sb.from(table).delete().eq('id', id);
      unawaited(_logAdminAction(
        'admin_delete_row',
        targetId: id,
        tableName: table,
        details: {'table': table},
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Spalten-Metadaten für eine Tabelle (für generische Create-Formulare).
  /// Whitelist im RPC verhindert Zugriff auf sensitive Tabellen.
  static Future<List<Map<String, dynamic>>> getTableColumns(
      String table) async {
    try {
      final res = await sb
          .rpc<dynamic>('admin_get_table_columns', params: {'p_table': table});
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Generisches INSERT für Admin-Create-Formulare. Liefert die
  /// erstellte Row zurück (mit auto-generierter id/created_at) oder null
  /// bei Fehler. Schreibt audit_logs (action='admin_create').
  static Future<Map<String, dynamic>?> insertRow({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    try {
      final res = await sb.from(table).insert(values).select().single();
      final newId = res['id'] as String?;
      unawaited(_logAdminAction(
        'admin_create',
        targetId: newId,
        tableName: table,
        details: {
          'table': table,
          // Werte loggen aber Längen-Cap auf 200 Chars um audit_logs schlank zu halten.
          'values': values.map((k, v) {
            final s = v?.toString() ?? 'null';
            return MapEntry(k, s.length > 200 ? '${s.substring(0, 200)}…' : s);
          }),
        },
      ));
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Generisches Feld-Update (z.B. is_banned/is_admin auf profiles).
  /// Schreibt audit_logs (action='admin_update_field').
  static Future<bool> updateField({
    required String table,
    required String id,
    required String column,
    required dynamic value,
  }) async {
    try {
      await sb.from(table).update({column: value}).eq('id', id);
      unawaited(_logAdminAction(
        'admin_update_field',
        targetId: id,
        tableName: table,
        details: {
          'table': table,
          'column': column,
          'value': () {
            final s = value?.toString() ?? 'null';
            return s.length > 200 ? '${s.substring(0, 200)}…' : s;
          }(),
        },
      ));
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
    String? role,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('admin_list_users', params: {
        'p_search': (search ?? '').isEmpty ? null : search,
        'p_only_unconfirmed': onlyUnconfirmed,
        'p_only_missing_profile': onlyMissingProfile,
        'p_role': (role ?? '').isEmpty ? null : role,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (_) {
      // Fallback wenn Migration noch nicht angewendet wurde
      return recent('profiles', orderBy: 'created_at');
    }
  }

  /// Anzahl aller User die den aktuellen Filtern entsprechen.
  /// Wird für die Pagination-Anzeige genutzt — verhindert dass User 101+
  /// versehentlich versteckt bleiben.
  static Future<int> countUsersViaRpc({
    String? search,
    bool onlyUnconfirmed = false,
    bool onlyMissingProfile = false,
    String? role,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('admin_count_users', params: {
        'p_search': (search ?? '').isEmpty ? null : search,
        'p_only_unconfirmed': onlyUnconfirmed,
        'p_only_missing_profile': onlyMissingProfile,
        'p_role': (role ?? '').isEmpty ? null : role,
      });
      if (res is int) return res;
      if (res is num) return res.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Web parity: audit log, reports, cleanup, user moderation, chat moderation.
  // ---------------------------------------------------------------------------

  /// Most recent audit-log entries with actor profile (best-effort).
  static Future<List<Map<String, dynamic>>> loadAuditLogs({
    int limit = 100,
    String? actionFilter,
    int? daysBack,
    String? actorSearch,
  }) async {
    try {
      var q = sb
          .from('audit_logs')
          .select('*, profiles!audit_logs_actor_id_fkey(name)');
      if (actionFilter != null && actionFilter.isNotEmpty) {
        // Group-Filter: 'create' matched admin_create, 'update' matched
        // admin_update_*, 'delete' matched admin_delete_row + delete_user
        // + delete_post, 'ban' matched ban_user + unban_user.
        switch (actionFilter) {
          case 'create':
            q = q.eq('action', 'admin_create');
            break;
          case 'update':
            q = q.or('action.eq.admin_update_field,action.eq.admin_update_status,action.eq.change_role');
            break;
          case 'delete':
            q = q.or('action.eq.admin_delete_row,action.eq.delete_user,action.eq.delete_post');
            break;
          case 'ban':
            q = q.or('action.eq.ban_user,action.eq.unban_user');
            break;
          default:
            q = q.eq('action', actionFilter);
        }
      }
      if (daysBack != null && daysBack > 0) {
        final since = DateTime.now()
            .subtract(Duration(days: daysBack))
            .toIso8601String();
        q = q.gte('created_at', since);
      }
      final rows = await q.order('created_at', ascending: false).limit(limit);
      var list =
          (rows as List).whereType<Map<String, dynamic>>().toList();
      // Actor-Search nur client-side weil Supabase keine sinnvolle
      // .or() auf joined columns unterstützt.
      if (actorSearch != null && actorSearch.trim().isNotEmpty) {
        final needle = actorSearch.trim().toLowerCase();
        list = list.where((r) {
          final p = r['profiles'];
          if (p is Map) {
            final n = (p['name'] as String?)?.toLowerCase() ?? '';
            if (n.contains(needle)) return true;
          }
          final aid = (r['actor_id'] as String?)?.toLowerCase() ?? '';
          return aid.contains(needle);
        }).toList();
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Count of currently pending content reports.
  static Future<int> openReportsCount() async {
    try {
      final rows = await sb
          .from('reports')
          .select('id')
          .eq('status', 'pending');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Trigger the scheduled cleanup RPC (returns summary map if available).
  static Future<Map<String, dynamic>?> runScheduledCleanup() async {
    try {
      final result = await sb.rpc<dynamic>('run_scheduled_cleanup');
      unawaited(_logAdminAction('cleanup'));
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'ok': true};
    } catch (_) {
      return null;
    }
  }

  /// Hard-delete a user via admin RPC (cascades auth + profile).
  static Future<bool> deleteUser(String userId) async {
    try {
      await sb.rpc<dynamic>('admin_delete_user', params: {'p_user_id': userId});
      unawaited(_logAdminAction('delete_user', targetId: userId));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Change a user's role via RPC; falls back to direct profile update.
  static Future<bool> changeUserRole(String userId, String newRole) async {
    try {
      await sb.rpc<dynamic>('admin_change_user_role', params: {
        'p_user_id': userId,
        'p_new_role': newRole,
      });
      unawaited(_logAdminAction('role_change',
          targetId: userId, details: {'new_role': newRole}));
      return true;
    } catch (_) {
      // Fallback: direct update via updateField
      final ok = await updateField(
          table: 'profiles', id: userId, column: 'role', value: newRole);
      if (ok) {
        unawaited(_logAdminAction('role_change_fallback',
            targetId: userId, details: {'new_role': newRole}));
      }
      return ok;
    }
  }

  /// Ban a user for [days] (default 30) with a German-language reason.
  static Future<bool> banUser(String userId, String reason,
      {int days = 30}) async {
    try {
      final until = DateTime.now()
          .add(Duration(days: days))
          .toUtc()
          .toIso8601String();
      await sb.from('profiles').update({
        'is_banned': true,
        'banned_until': until,
        'ban_reason': reason,
      }).eq('id', userId);
      unawaited(_logAdminAction('ban',
          targetId: userId,
          details: {'reason': reason, 'days': days, 'until': until}));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lift a user ban.
  static Future<bool> unbanUser(String userId) async {
    try {
      await sb.from('profiles').update({
        'is_banned': false,
        'banned_until': null,
        'ban_reason': null,
      }).eq('id', userId);
      unawaited(_logAdminAction('unban', targetId: userId));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget Audit-Log via log_admin_action RPC. Schluckt Fehler
  /// damit fehlgeschlagenes Logging nicht die eigentliche Aktion blockt.
  static Future<void> _logAdminAction(
    String action, {
    String? targetId,
    String? tableName,
    Map<String, dynamic>? details,
  }) async {
    try {
      await sb.rpc<dynamic>('log_admin_action', params: {
        'p_action': action,
        if (targetId != null) 'p_target_id': targetId,
        if (tableName != null) 'p_table_name': tableName,
        'p_details': details ?? <String, dynamic>{},
      });
    } catch (_) {/* fail-silent */}
  }

  /// Find the global community chat room.
  static Future<Map<String, dynamic>?> getCommunityRoom() async {
    try {
      final row = await sb
          .from('conversations')
          .select('id, is_locked, locked_reason')
          .eq('type', 'system')
          .eq('title', 'Community Chat')
          .maybeSingle();
      if (row != null) return row;
    } catch (_) {}
    try {
      final row = await sb
          .from('conversations')
          .select('id, is_locked, locked_reason')
          .eq('type', 'system')
          .or('title.eq.Allgemein,title.ilike.%community%')
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  /// Most recent chat messages for a conversation (newest first).
  static Future<List<Map<String, dynamic>>> getChatMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    try {
      final rows = await sb
          .from('messages')
          .select(
              'id, content, created_at, deleted_at, sender_id, conversation_id, profiles(name, email)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Lock or unlock a conversation (sets locked_by/at/reason accordingly).
  static Future<bool> toggleChatLock(
    String conversationId,
    bool lock, {
    String? reason,
  }) async {
    try {
      final uid = sb.auth.currentUser?.id;
      await sb.from('conversations').update({
        'is_locked': lock,
        'locked_by': lock ? uid : null,
        'locked_at': lock ? DateTime.now().toUtc().toIso8601String() : null,
        'locked_reason': lock ? reason : null,
      }).eq('id', conversationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a message: prefer hard-delete RPC, fall back to soft-delete column.
  static Future<bool> softDeleteMessage(String messageId) async {
    try {
      await sb.rpc<dynamic>('admin_hard_delete_message',
          params: {'p_message_id': messageId});
      return true;
    } catch (_) {
      try {
        await sb.from('messages').update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', messageId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// List users banned from the chat (joined to their profiles).
  static Future<List<Map<String, dynamic>>> getChatBannedUsers() async {
    try {
      final rows = await sb
          .from('chat_banned_users')
          .select('user_id, profiles(id, name, email)');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Toggle a chat-ban for [userId]; pass current state to avoid extra read.
  static Future<bool> toggleChatBan(String userId, bool currentlyBanned) async {
    try {
      if (currentlyBanned) {
        await sb.from('chat_banned_users').delete().eq('user_id', userId);
      } else {
        final uid = sb.auth.currentUser?.id;
        await sb.from('chat_banned_users').insert({
          'user_id': userId,
          'banned_by': uid,
          'reason': 'Admin-Entscheidung',
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin-Broadcast: sendet eine Ankündigung als Notification an ALLE
  /// Nutzer:innen (server-seitig via SECURITY-DEFINER-RPC, admin-only).
  /// Gibt die Anzahl erreichter Profile zurück oder null bei Fehler.
  static Future<int?> broadcastNotification({
    required String title,
    required String body,
    String? link,
    String priority = 'normal',
  }) async {
    try {
      final res = await sb.rpc<dynamic>(
        'admin_broadcast_notification',
        params: {
          'p_title': title,
          'p_body': body,
          'p_link': (link != null && link.trim().isNotEmpty)
              ? link.trim()
              : null,
          'p_priority': priority,
        },
      );
      if (res is int) return res;
      if (res is num) return res.toInt();
      return int.tryParse('$res');
    } catch (_) {
      return null;
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
    this.activeUsers30d = 0,
    this.newUsers7d = 0,
    this.newPosts7d = 0,
    this.activePosts = 0,
    this.totalMessages = 0,
    this.totalConversations = 0,
    this.upcomingEvents = 0,
    this.activeBoardPosts = 0,
    this.activeCrises = 0,
    this.verifiedOrganizations = 0,
    this.verifiedFarms = 0,
    this.totalTrustRatings = 0,
    this.avgTrustScore = 0.0,
    this.totalGroups = 0,
    this.activeGroups = 0,
    this.totalChallenges = 0,
    this.activeChallenges = 0,
    this.totalTimebankHours = 0.0,
    this.totalTimebankEntries = 0,
    this.totalNotifications = 0,
    this.unreadNotifications = 0,
    this.totalSavedPosts = 0,
    this.openReports = 0,
    this.activeUsers24h = 0,
    this.activeUsers7d = 0,
    this.newUsers24h = 0,
    this.newUsers30d = 0,
    this.admins = 0,
    this.moderators = 0,
    this.bannedUsers = 0,
  });

  final int users;
  final int posts;
  final int events;
  final int boardPosts;
  final int crises;
  final int organizations;
  final int farms;
  final int reports;
  final int activeUsers30d;
  final int newUsers7d;
  final int newPosts7d;
  final int activePosts;
  final int totalMessages;
  final int totalConversations;
  final int upcomingEvents;
  final int activeBoardPosts;
  final int activeCrises;
  final int verifiedOrganizations;
  final int verifiedFarms;
  final int totalTrustRatings;
  final double avgTrustScore;
  final int totalGroups;
  final int activeGroups;
  final int totalChallenges;
  final int activeChallenges;
  final double totalTimebankHours;
  final int totalTimebankEntries;
  final int totalNotifications;
  final int unreadNotifications;
  final int totalSavedPosts;
  final int openReports;
  // Erweiterte Nutzer-Metriken (client-seitig befüllt, keine RPC-Migration).
  final int activeUsers24h;
  final int activeUsers7d;
  final int newUsers24h;
  final int newUsers30d;
  final int admins;
  final int moderators;
  final int bannedUsers;
}

class _UsersOverview {
  const _UsersOverview({
    this.active24h = 0,
    this.active7d = 0,
    this.newUsers24h = 0,
    this.newUsers30d = 0,
    this.admins = 0,
    this.moderators = 0,
    this.bannedUsers = 0,
  });

  final int active24h;
  final int active7d;
  final int newUsers24h;
  final int newUsers30d;
  final int admins;
  final int moderators;
  final int bannedUsers;
}

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  return AdminRepository.stats();
});

final adminAuditLogsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => AdminRepository.loadAuditLogs(),
);

final adminOpenReportsProvider = FutureProvider<int>(
  (ref) => AdminRepository.openReportsCount(),
);
