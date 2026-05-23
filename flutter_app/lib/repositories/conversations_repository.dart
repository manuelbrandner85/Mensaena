import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Conversations + Messages. Realtime-Subscribe pro Conversation.
class ConversationsRepository {
  const ConversationsRepository._();

  /// Eigene Konversationen sortiert nach last_message_at (neueste oben).
  static Future<List<Map<String, dynamic>>> listMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final memberships = await sb
          .from('conversation_members')
          .select('conversation_id, last_read_at, '
              'conversations(id,type,title,updated_at,created_at)')
          .eq('user_id', uid);
      final rows = (memberships as List).whereType<Map<String, dynamic>>();
      final result = <Map<String, dynamic>>[];
      for (final r in rows) {
        final conv = r['conversations'] as Map<String, dynamic>?;
        if (conv == null) continue;
        result.add({
          ...conv,
          'last_read_at': r['last_read_at'],
        });
      }
      result.sort((a, b) {
        final ta = DateTime.tryParse(
                (a['updated_at'] ?? a['created_at']) as String? ?? '') ??
            DateTime(2000);
        final tb = DateTime.tryParse(
                (b['updated_at'] ?? b['created_at']) as String? ?? '') ??
            DateTime(2000);
        return tb.compareTo(ta);
      });
      return result;
    } catch (_) {
      return const [];
    }
  }
}

class MessagesRepository {
  const MessagesRepository._();

  /// Realtime-Stream der Messages einer Conversation, sortiert aufsteigend.
  static Stream<List<Map<String, dynamic>>> watch(String conversationId) {
    return sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) {
          final list = rows.where((r) => r['deleted_at'] == null).toList()
            ..sort((a, b) {
              final ta = DateTime.tryParse(a['created_at'] as String? ?? '') ??
                  DateTime(2000);
              final tb = DateTime.tryParse(b['created_at'] as String? ?? '') ??
                  DateTime(2000);
              return ta.compareTo(tb);
            });
          return list;
        });
  }

  static Future<bool> send({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
      });
      // Touch conversation.updated_at fuer Sort-Order.
      await sb
          .from('conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', conversationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markRead(String conversationId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .eq('conversation_id', conversationId);
    } catch (_) {}
  }
}

final messagesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, conversationId) {
  return MessagesRepository.watch(conversationId);
});
