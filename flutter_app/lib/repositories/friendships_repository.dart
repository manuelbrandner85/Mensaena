/// SKILL: mensaena-features (UX-Welle1 P2)
/// Freundschaftsanfragen — bidirectional bestätigt (anders als Follow,
/// das einseitig ist).
library;

import '../services/supabase_service.dart';

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

  /// Anfrage senden.
  static Future<bool> request(String addresseeId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null || me == addresseeId) return false;
    try {
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

  /// Eingehende Anfrage akzeptieren.
  static Future<bool> accept(String requesterId) async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return false;
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
