import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

/// Repository für DM/Chat. Kapselt alle Supabase-Queries für Conversations,
/// Conversation-Members und Messages. Tabellen-/Spalten-Namen sind 1:1
/// identisch zur Web-App – kein Schema-Wechsel.
class MessagesRepository {
  MessagesRepository();

  /// Lädt alle Conversations des Users mit jeweils der letzten Nachricht
  /// und dem ungelesenen-Counter (basierend auf last_read_at).
  Future<List<Conversation>> listConversations(String userId) async {
    // Members + Konversation + andere Mitglieder + last_read_at
    final memberRows = await sb
        .from('conversation_members')
        .select(
          'conversation_id, last_read_at, '
          'conversations!inner(id, type, title, created_at)',
        )
        .eq('user_id', userId);

    if (memberRows is! List) return const [];

    final conversations = <Conversation>[];

    for (final row in memberRows) {
      final r = row as Map<String, dynamic>;
      final convData = r['conversations'] as Map<String, dynamic>?;
      if (convData == null) continue;
      if (convData['type'] == 'system') continue;

      final convId = convData['id'] as String;
      final lastReadStr = r['last_read_at'] as String?;
      final lastRead = lastReadStr != null ? DateTime.tryParse(lastReadStr) : null;

      // Letzte Nachricht
      final msgRows = await sb
          .from('messages')
          .select('id, conversation_id, sender_id, content, created_at, read_at, deleted_at')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1);
      Message? lastMessage;
      if (msgRows is List && msgRows.isNotEmpty) {
        lastMessage = Message.fromJson(msgRows.first as Map<String, dynamic>);
      }

      // Unread-Count
      var unread = 0;
      if (lastRead != null) {
        final unreadRows = await sb
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .neq('sender_id', userId)
            .gt('created_at', lastRead.toIso8601String());
        if (unreadRows is List) unread = unreadRows.length;
      }

      // Anderes Mitglied (für Direct-Conversations)
      Profile? other;
      if (convData['type'] == 'direct') {
        final others = await sb
            .from('conversation_members')
            .select('user_id, profiles!inner(id, name, avatar_url)')
            .eq('conversation_id', convId)
            .neq('user_id', userId)
            .limit(1);
        if (others is List && others.isNotEmpty) {
          final p = (others.first as Map<String, dynamic>)['profiles'];
          if (p is Map<String, dynamic>) other = Profile.fromJson(p);
        }
      }

      conversations.add(
        Conversation.fromJson(convData).copyWith(
          lastMessage: lastMessage,
          unreadCount: unread,
          otherProfile: other,
        ),
      );
    }

    // Sortiere nach last-message-time absteigend
    conversations.sort((a, b) {
      final at = a.lastMessage?.createdAt ?? a.createdAt;
      final bt = b.lastMessage?.createdAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    return conversations;
  }

  /// Lädt die Nachrichten eines Conversations (chronologisch aufsteigend).
  Future<List<Message>> listMessages(String conversationId, {int limit = 100}) async {
    final rows = await sb
        .from('messages')
        .select(
          'id, conversation_id, sender_id, content, created_at, read_at, deleted_at, '
          'profiles:sender_id(id, name, avatar_url)',
        )
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);
    if (rows is! List) return const [];
    return rows
        .map((r) => Message.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Sendet eine neue Nachricht. Realtime-Subscription informiert alle Member.
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final res = await sb.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
    }).select('id, conversation_id, sender_id, content, created_at, read_at').single();
    return Message.fromJson(res);
  }

  /// Markiert die Conversation als gelesen, setzt last_read_at = now().
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await sb
        .from('conversation_members')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  /// Findet oder erstellt eine 1:1-Direct-Conversation zwischen zwei Usern.
  Future<String> findOrCreateDirectConversation({
    required String userA,
    required String userB,
  }) async {
    final rows = await sb
        .from('conversation_members')
        .select('conversation_id, conversations!inner(type)')
        .eq('user_id', userA);
    if (rows is List) {
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        if ((m['conversations'] as Map?)?['type'] != 'direct') continue;
        final convId = m['conversation_id'] as String;
        final others = await sb
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', convId);
        if (others is List) {
          final ids = others.map((o) => (o as Map)['user_id']).toSet();
          if (ids.length == 2 && ids.contains(userB)) return convId;
        }
      }
    }
    // Neu anlegen
    final conv = await sb
        .from('conversations')
        .insert({'type': 'direct'})
        .select('id')
        .single();
    final convId = conv['id'] as String;
    await sb.from('conversation_members').insert([
      {'conversation_id': convId, 'user_id': userA},
      {'conversation_id': convId, 'user_id': userB},
    ]);
    return convId;
  }

  /// Realtime-Stream für neue Nachrichten in einer Conversation.
  Stream<Message> messagesStream(String conversationId) {
    final controller = StreamController<Message>.broadcast();
    final channel = sb.channel('messages:$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord;
        controller.add(Message.fromJson(newRow));
      },
    ).subscribe();
    controller.onCancel = () {
      sb.removeChannel(channel);
    };
    return controller.stream;
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => MessagesRepository(),
);

/// Liste aller Conversations des aktuellen Users.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.listConversations(user.id);
});

/// Nachrichten einer Conversation.
final conversationMessagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.listMessages(conversationId);
});

/// Realtime-Stream für eine Conversation.
final conversationStreamProvider =
    StreamProvider.family<Message, String>((ref, conversationId) {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.messagesStream(conversationId);
});
