import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.read(supabaseProvider)),
);

class ChatRepository {
  ChatRepository(this._db);
  final SupabaseClient _db;

  // ── Channels ──────────────────────────────────────────────────────────────

  Future<List<ChatChannel>> loadChannels() async {
    final data = await _db
        .from('chat_channels')
        .select('*')
        .order('sort_order', ascending: true);
    if (data.isEmpty) return [];
    return data.map((e) => ChatChannel.fromJson(e)).toList();
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<ChannelMessage>> loadMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    var query = _db
        .from('messages')
        .select(
          'id, conversation_id, sender_id, content, created_at, deleted_at, '
          'edited_at, reply_to_id, is_pinned, '
          'profiles:sender_id(id, name, avatar_url, nickname)',
        )
        .eq('conversation_id', conversationId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    if (before != null) {
      query = query.lt('created_at', before);
    }

    final rows = await query;
    final messages = rows.map((e) => ChannelMessage.fromJson(e)).toList();

    if (messages.isEmpty) return [];

    // Load reactions for this batch
    final ids = messages.map((m) => m.id).toList();
    try {
      final reactionsData = await _db
          .from('message_reactions')
          .select('*')
          .inFilter('message_id', ids);
      final reactions = reactionsData.map((e) => MessageReaction.fromJson(e)).toList();
      final reactionsById = <String, List<MessageReaction>>{};
      for (final r in reactions) {
        reactionsById.putIfAbsent(r.messageId, () => []).add(r);
      }
      return messages
          .map((m) => m.copyWith(reactions: reactionsById[m.id] ?? []))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return messages.reversed.toList();
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Nicht eingeloggt');
    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content.trim(),
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    final existing = await _db
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();
    if (existing != null) {
      await _db
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
    } else {
      await _db.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  Future<void> pinMessage(String messageId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db.from('message_pins').insert({
      'message_id': messageId,
      'pinned_by': userId,
    });
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  Stream<ChannelMessage> messageStream(String conversationId) {
    final controller = StreamController<ChannelMessage>.broadcast();
    final channel = _db.channel('chat-messages-$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final row = payload.newRecord;
        if (row.isEmpty) return;
        if (row['conversation_id'] != conversationId) return;
        // Fetch sender profile
        try {
          final profile = await _db
              .from('profiles')
              .select('id, name, avatar_url, nickname')
              .eq('id', row['sender_id'] as String)
              .maybeSingle();
          final enriched = Map<String, dynamic>.from(row);
          if (profile != null) enriched['profiles'] = profile;
          controller.add(ChannelMessage.fromJson(enriched));
        } catch (_) {
          controller.add(ChannelMessage.fromJson(row));
        }
      },
    ).subscribe();
    controller.onCancel = () => _db.removeChannel(channel);
    return controller.stream;
  }
}
