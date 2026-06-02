/// SKILL: mensaena-features (UX-Welle1 P2)
/// Freundschaftsanfragen — bidirectional bestätigt (anders als Follow,
/// das einseitig ist).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Anzahl eingehender, noch offener Freundschaftsanfragen (für Drawer-Badge).
final incomingFriendRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final list = await FriendshipsRepository.incoming();
  return list.length;
});

enum FriendshipState {
  none, // keine Verbindung
  outgoingPending, // ich habe angefragt
  incomingPending, // andere:r hat angefragt
  accepted,
  declined,
}

class FriendshipsRepository {
  const FriendshipsRepository._();

  /// Status meiner Beziehung mit [otherId].
  static Future<FriendshipState> stateWith(String otherId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null || me == otherId) return FriendshipState.none;
    try {
      final rows = await sb
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or('and(requester_id.eq.$me,addressee_id.eq.$otherId),and(requester_id.eq.$otherId,addressee_id.eq.$me)')
          .limit(1);
      final list = (rows as List).whereType<Map<String, dynamic>>().toList();
      if (list.isEmpty) return FriendshipState.none;
      final row = list.first;
      final status = row['status'] as String? ?? 'pending';
      if (status == 'accepted') return FriendshipState.accepted;
      if (status == 'declined') return FriendshipState.declined;
      final isOutgoing = row['requester_id'] == me;
      return isOutgoing
          ? FriendshipState.outgoingPending
          : FriendshipState.incomingPending;
    } catch (_) {
      return FriendshipState.none;
    }
  }

  /// Anfrage senden. Falls die GEGENSEITE bereits eine pending-Anfrage an
  /// MICH hat → direkt akzeptieren (häufige UX-Falle: A schickt an B, B
  /// öffnet B's Profil und tappt "Anfragen" — vorher gab das eine
  /// Unique-Constraint-Verletzung, jetzt entsteht eine Freundschaft).
  static Future<bool> request(String addresseeId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null || me == addresseeId) return false;
    try {
      // 1) Existiert bereits eine pending-Anfrage von der Gegenseite → accept.
      final existing = await sb
          .from('friendships')
          .select('requester_id, status')
          .eq('requester_id', addresseeId)
          .eq('addressee_id', me)
          .maybeSingle();
      if (existing != null && existing['status'] == 'pending') {
        return accept(addresseeId);
      }
      // 2) Sonst neue pending-Row anlegen (Unique-Constraint verhindert
      //    Mehrfach-Anfragen in die gleiche Richtung).
      await sb.from('friendships').insert({
        'requester_id': me,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eingehende Anfrage akzeptieren. Nutzt server-seitigen RPC mit
  /// SECURITY DEFINER → idempotent, kein Race-Condition mit RLS.
  static Future<bool> accept(String requesterId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return false;
    try {
      final res = await sb.rpc<dynamic>(
        'accept_friend_request',
        params: {'p_requester': requesterId},
      );
      return res == true;
    } catch (_) {
      // Fallback auf direktes Update — alte App-Version, RPC fehlt.
      try {
        await sb
            .from('friendships')
            .update({
              'status': 'accepted',
              'responded_at': DateTime.now().toIso8601String(),
            })
            .eq('requester_id', requesterId)
            .eq('addressee_id', me);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Eingehende Anfrage ablehnen.
  static Future<bool> decline(String requesterId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return false;
    try {
      await sb
          .from('friendships')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('requester_id', requesterId)
          .eq('addressee_id', me);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigene gesendete Anfrage zurückziehen ODER Freundschaft beenden.
  static Future<bool> remove(String otherId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return false;
    try {
      await sb
          .from('friendships')
          .delete()
          .or('and(requester_id.eq.$me,addressee_id.eq.$otherId),and(requester_id.eq.$otherId,addressee_id.eq.$me)');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// ZUSATZ-4D: Vorschläge "Personen die du kennen könntest".
  /// Heuristik: gleiche neighborhood_group / region, NICHT bereits in
  /// einer Friendship-Row mit mir (egal welcher Status), nicht self,
  /// nicht geblockt. Max [limit] Treffer.
  static Future<List<Map<String, dynamic>>> suggestions({int limit = 10}) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const [];
    try {
      // Bereits bestehende Beziehungen (egal welcher Status) ausschließen.
      final existingRows = await sb
          .from('friendships')
          .select('requester_id, addressee_id')
          .or('requester_id.eq.$me,addressee_id.eq.$me');
      final excludeIds = <String>{me};
      for (final r in (existingRows as List).whereType<Map<String, dynamic>>()) {
        final req = r['requester_id'] as String?;
        final add = r['addressee_id'] as String?;
        if (req != null && req != me) excludeIds.add(req);
        if (add != null && add != me) excludeIds.add(add);
      }
      // Optional: Auch geblockte/blockierende User ausschließen.
      final blockRows = await sb
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$me,blocked_id.eq.$me');
      for (final r in (blockRows as List).whereType<Map<String, dynamic>>()) {
        final b = r['blocker_id'] as String?;
        final t = r['blocked_id'] as String?;
        if (b != null && b != me) excludeIds.add(b);
        if (t != null && t != me) excludeIds.add(t);
      }
      // Meine Region holen.
      final my = await sb
          .from('profiles')
          .select('region_id, neighborhood_group_id')
          .eq('id', me)
          .maybeSingle();
      var query = sb
          .from('profiles')
          .select('id, display_name, name, avatar_url, region_id')
          .filter('is_banned', 'eq', false)
          .not('id', 'in',
              '(${excludeIds.map((id) => '"$id"').join(',')})');
      final regionId = my?['region_id'] as String?;
      if (regionId != null) query = query.eq('region_id', regionId);
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Globale User-Suche zum Freunde-Finden. Sucht über display_name, name
  /// und nickname (case-insensitive), schließt sich selbst + geblockte aus.
  /// Liefert pro Treffer das Profil + den aktuellen Friendship-Status, damit
  /// die UI den richtigen Button zeigen kann (Anfragen / Angefragt /
  /// Annehmen / Befreundet).
  static Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int limit = 30,
  }) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final esc = q.replaceAll('%', r'\%').replaceAll(',', '');
      final rows = await sb
          .from('profiles')
          .select('id, display_name, name, avatar_url')
          .filter('is_banned', 'eq', false)
          .neq('id', me)
          .or('display_name.ilike.%$esc%,name.ilike.%$esc%,nickname.ilike.%$esc%')
          .limit(limit);
      final profiles =
          (rows as List).whereType<Map<String, dynamic>>().toList();
      if (profiles.isEmpty) return const [];

      // Alle Friendship-Rows die mich + einen der Treffer betreffen, holen.
      final ids = profiles.map((p) => p['id'] as String).toList();
      final frRows = await sb
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or('requester_id.eq.$me,addressee_id.eq.$me');
      final stateById = <String, FriendshipState>{};
      for (final r in (frRows as List).whereType<Map<String, dynamic>>()) {
        final req = r['requester_id'] as String?;
        final add = r['addressee_id'] as String?;
        final status = r['status'] as String? ?? 'pending';
        final other = req == me ? add : req;
        if (other == null || !ids.contains(other)) continue;
        FriendshipState st;
        if (status == 'accepted') {
          st = FriendshipState.accepted;
        } else if (status == 'declined') {
          st = FriendshipState.declined;
        } else {
          st = req == me
              ? FriendshipState.outgoingPending
              : FriendshipState.incomingPending;
        }
        stateById[other] = st;
      }
      // Geblockte ausschließen.
      final blockRows = await sb
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$me,blocked_id.eq.$me');
      final blocked = <String>{};
      for (final r in (blockRows as List).whereType<Map<String, dynamic>>()) {
        final b = r['blocker_id'] as String?;
        final t = r['blocked_id'] as String?;
        if (b != null && b != me) blocked.add(b);
        if (t != null && t != me) blocked.add(t);
      }
      return profiles
          .where((p) => !blocked.contains(p['id']))
          .map((p) => {
                ...p,
                'friendship_state':
                    (stateById[p['id']] ?? FriendshipState.none).name,
              })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Liste eingehender pending-Anfragen für mich.
  static Future<List<Map<String, dynamic>>> incoming() async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const [];
    try {
      final rows = await sb
          .from('friendships')
          .select('requester_id, created_at, profiles!friendships_requester_id_fkey(id, display_name, avatar_url)')
          .eq('addressee_id', me)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Von mir gesendete, noch offene Anfragen (für "Gesendet"-Liste).
  static Future<List<Map<String, dynamic>>> outgoing() async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const [];
    try {
      final rows = await sb
          .from('friendships')
          .select('addressee_id, created_at, profiles!friendships_addressee_id_fkey(id, display_name, avatar_url)')
          .eq('requester_id', me)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Bestätigte Freunde.
  static Future<List<Map<String, dynamic>>> friends() async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const [];
    try {
      final rows = await sb
          .from('friendships')
          .select('requester_id, addressee_id, profiles_req:profiles!friendships_requester_id_fkey(id, display_name, avatar_url), profiles_addr:profiles!friendships_addressee_id_fkey(id, display_name, avatar_url)')
          .or('requester_id.eq.$me,addressee_id.eq.$me')
          .eq('status', 'accepted')
          .limit(500);
      // Pick the OTHER profile for each row.
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) {
            final isReq = r['requester_id'] == me;
            return (isReq ? r['profiles_addr'] : r['profiles_req'])
                as Map<String, dynamic>?;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
