import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/conversation.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService(this._client);

  // Conversations
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final data = await _client
        .from('conversation_members')
        .select('''
          conversation_id,
          last_read_at,
          role,
          conversations(
            id, type, title, post_id, is_locked, updated_at, created_at
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final result = List<Map<String, dynamic>>.from(data);

    // For DMs, resolve the other participant's name
    for (final entry in result) {
      final conv = entry['conversations'] as Map<String, dynamic>?;
      if (conv == null) continue;
      final convId = conv['id'] as String?;
      final type = conv['type'] as String?;
      if (type == 'direct' && convId != null && (conv['title'] == null || conv['title'] == '')) {
        try {
          final members = await _client
              .from('conversation_members')
              .select('user_id, profiles(id, name, nickname, avatar_url)')
              .eq('conversation_id', convId)
              .neq('user_id', userId)
              .limit(1);
          if (members is List && members.isNotEmpty) {
            final profile = members[0]['profiles'] as Map<String, dynamic>?;
            if (profile != null) {
              final name = profile['nickname'] as String? ?? profile['name'] as String? ?? 'Unbekannt';
              conv['title'] = name;
              conv['other_avatar'] = profile['avatar_url'];
            }
          }
        } catch (_) {}
      }
    }

    return result;
  }

  Future<Conversation?> getConversation(String conversationId) async {
    final data = await _client
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .maybeSingle();
    if (data == null) return null;
    return Conversation.fromJson(data);
  }

  Future<List<ConversationMember>> getMembers(String conversationId) async {
    final data = await _client
        .from('conversation_members')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('conversation_id', conversationId);
    return (data as List).map((e) => ConversationMember.fromJson(e)).toList();
  }

  Future<String> getOrCreateDMConversation(
      String userId, String otherUserId) async {
    try {
      final data = await _client.rpc('open_or_create_dm', params: {
        'other_user_id': otherUserId,
      });
      if (data != null && data is Map && data['conversation_id'] != null) {
        return data['conversation_id'] as String;
      }
    } catch (_) {}

    // Fallback: manual lookup
    final existing = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId);

    final otherConvs = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', otherUserId);

    final otherIds = (otherConvs as List).map((e) => e['conversation_id'] as String).toSet();

    for (final entry in existing) {
      final convId = entry['conversation_id'] as String;
      if (!otherIds.contains(convId)) continue;
      final conv = await _client.from('conversations').select().eq('id', convId).eq('type', 'direct').maybeSingle();
      if (conv != null) return convId;
    }

    final conv = await _client.from('conversations').insert({'type': 'direct'}).select().single();
    final convId = conv['id'] as String;

    await _client.from('conversation_members').insert([
      {'conversation_id': convId, 'user_id': userId, 'role': 'owner'},
      {'conversation_id': convId, 'user_id': otherUserId, 'role': 'member'},
    ]);

    return convId;
  }

  // Messages
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client
        .from('messages')
        .select('*, profiles!messages_sender_id_fkey(id, name, nickname, avatar_url)')
        .eq('conversation_id', conversationId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? replyToId,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
          'reply_to_id': replyToId,
        })
        .select('*, profiles!messages_sender_id_fkey(id, name, nickname, avatar_url)')
        .single();
    return Message.fromJson(data);
  }

  Future<void> editMessage(String messageId, String content) async {
    await _client.from('messages').update({
      'content': content,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    await _client
        .from('conversation_members')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  // Reactions
  Future<void> addReaction(
      String messageId, String userId, String emoji) async {
    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(
      String messageId, String userId, String emoji) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  // Community Channels
  Future<List<Map<String, dynamic>>> getChatChannels() async {
    final data = await _client
        .from('chat_channels')
        .select()
        .eq('is_locked', false)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  // Realtime
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message) onNewMessage,
  ) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNewMessage(Message.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  // User Status
  Future<void> setUserStatus(String userId, String status) async {
    await _client.from('user_status').upsert({
      'user_id': userId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Unread counts
  Future<int> getUnreadCount(String userId) async {
    try {
      final data = await _client
          .from('v_unread_counts')
          .select('unread_count')
          .eq('user_id', userId);
      int total = 0;
      for (final row in data) {
        total += (row['unread_count'] as int? ?? 0);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
