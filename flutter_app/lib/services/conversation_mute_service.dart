/// SKILL: mensaena-features (P2) — Mute-Toggle pro Conversation.
library;

import '../services/supabase_service.dart';

class ConversationMuteService {
  ConversationMuteService._();
  static final ConversationMuteService instance = ConversationMuteService._();

  Future<bool> isMuted(String conversationId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('conversation_members')
          .select('is_muted, muted_until')
          .eq('conversation_id', conversationId)
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return false;
      final muted = row['is_muted'] as bool? ?? false;
      if (!muted) return false;
      final untilStr = row['muted_until'] as String?;
      if (untilStr == null) return true;
      final until = DateTime.tryParse(untilStr)?.toUtc();
      if (until == null) return true;
      return until.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> setMuted(String conversationId,
      {bool muted = true, Duration? duration}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('conversation_members')
          .update({
            'is_muted': muted,
            'muted_until':
                duration == null ? null : DateTime.now().add(duration).toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', uid);
    } catch (_) {}
  }
}
