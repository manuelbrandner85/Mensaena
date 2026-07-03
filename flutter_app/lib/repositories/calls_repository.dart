/// SKILL: supabase
/// CallsRepository — Datenzugriffe der Call-Domäne (scheduled_calls,
/// call_voicemails, dm_calls-Historie) aus der UI-Schicht gebündelt.
/// Live-Call-Lifecycle (start/answer/decline/status) bleibt bewusst im
/// DmCallService — hier liegt nur das CRUD der Begleit-Features.
library;

import '../services/supabase_service.dart';

class CallsRepository {
  const CallsRepository._();

  // ── Geplante Anrufe (P3) ────────────────────────────────────────────

  /// Kommende, nicht abgesagte Termine, an denen ich beteiligt bin.
  static Future<List<Map<String, dynamic>>> scheduledUpcoming() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('scheduled_calls')
          .select(
              '*, caller:caller_id(id, display_name, avatar_url), callee:callee_id(id, display_name, avatar_url)')
          .or('caller_id.eq.$uid,callee_id.eq.$uid')
          .eq('is_cancelled', false)
          .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .order('scheduled_at', ascending: true)
          .limit(50);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> scheduleCreate({
    required String calleeId,
    required DateTime scheduledAt,
    required String callType,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('scheduled_calls').insert({
        'caller_id': uid,
        'callee_id': calleeId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'call_type': callType,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> scheduleCancel(String id) async {
    try {
      await sb
          .from('scheduled_calls')
          .update({'is_cancelled': true}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Voicemails (F15) ────────────────────────────────────────────────

  /// An mich gerichtete Voicemails, neueste zuerst.
  static Future<List<Map<String, dynamic>>> voicemailsForMe() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('call_voicemails')
          .select('*, caller:caller_id (id, display_name, avatar_url)')
          .eq('callee_id', uid)
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> voicemailMarkListened(String id) async {
    await sb
        .from('call_voicemails')
        .update({'is_listened': true}).eq('id', id);
  }

  /// Voicemail senden (Audio bereits in Storage). true bei Erfolg.
  static Future<bool> sendVoicemail({
    required String calleeId,
    required String audioUrl,
    required int seconds,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('call_voicemails').insert({
        'caller_id': uid,
        'callee_id': calleeId,
        'audio_url': audioUrl,
        'duration_seconds': seconds,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Anruf-Historie ──────────────────────────────────────────────────

  /// Letzte 30 Calls, an denen ich beteiligt und die ich nicht
  /// ausgeblendet habe — mit Profil-Join + Fallback ohne Embed
  /// (manche Supabase-Setups erlauben den FK-Embed nicht).
  static Future<List<Map<String, dynamic>>> history(String myId) async {
    const visible =
        'and(caller_id.eq.{id},caller_hidden_at.is.null),and(callee_id.eq.{id},callee_hidden_at.is.null)';
    final filter = visible.replaceAll('{id}', myId);
    try {
      final rows = await sb
          .from('dm_calls')
          .select('id, caller_id, callee_id, call_type, status, '
              'created_at, answered_at, ended_at, conversation_id, room_name, '
              'caller_hidden_at, callee_hidden_at, '
              'caller:profiles!dm_calls_caller_id_fkey(id,display_name,name,avatar_url),'
              'callee:profiles!dm_calls_callee_id_fkey(id,display_name,name,avatar_url)')
          .or(filter)
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      try {
        final rows = await sb
            .from('dm_calls')
            .select()
            .or(filter)
            .order('created_at', ascending: false)
            .limit(30);
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
  }
}
