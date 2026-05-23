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

  /// Reaktion auf eine Message hinzufuegen/entfernen (Toggle).
  /// Schema: message_reactions(message_id, user_id, emoji).
  static Future<bool> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .eq('emoji', emoji)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('message_reactions')
            .delete()
            .eq('id', existing['id'] as Object);
        return true;
      }
      await sb.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': uid,
        'emoji': emoji,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Realtime: alle Reaktionen einer Conversation (joinable).
  static Stream<List<Map<String, dynamic>>> watchReactions(
      String conversationId) {
    return sb
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .where((r) =>
                r['conversation_id'] == null ||
                r['conversation_id'] == conversationId)
            .toList());
  }

  /// Live-Stream der last_read_at-Werte der anderen Mitglieder
  /// (fuer Read-Receipts: "Gelesen am ...").
  static Stream<DateTime?> watchPeerLastRead(String conversationId) {
    final uid = SupabaseService.currentUser?.id;
    return sb
        .from('conversation_members')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', conversationId)
        .map((rows) {
          final peers = rows.where((r) => r['user_id'] != uid);
          DateTime? latest;
          for (final p in peers) {
            final ts =
                DateTime.tryParse(p['last_read_at'] as String? ?? '');
            if (ts != null && (latest == null || ts.isAfter(latest))) {
              latest = ts;
            }
          }
          return latest;
        });
  }
}

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ConversationsRepository.listMine();
});

final messagesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, conversationId) {
  return MessagesRepository.watch(conversationId);
});

/// Stream der zuletzt-gelesen-Zeit der anderen Mitglieder (fuer Read-Receipts).
final peerLastReadProvider =
    StreamProvider.family<DateTime?, String>((ref, conversationId) {
  return MessagesRepository.watchPeerLastRead(conversationId);
});
