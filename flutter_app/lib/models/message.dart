/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `messages` (gyqujitkvymlmgroovch).
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.receiverId,
    this.readAt,
    this.deletedAt,
    this.replyToId,
    this.editedAt,
    this.isPinned = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? receiverId;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final String? replyToId;
  final DateTime? editedAt;
  final bool isPinned;

  factory Message.fromJson(Map<String, dynamic> j) {
    return Message(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      senderId: j['sender_id'] as String,
      content: j['content'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      receiverId: j['receiver_id'] as String?,
      readAt: j['read_at'] != null
          ? DateTime.tryParse(j['read_at'] as String)
          : null,
      deletedAt: j['deleted_at'] != null
          ? DateTime.tryParse(j['deleted_at'] as String)
          : null,
      replyToId: j['reply_to_id'] as String?,
      editedAt: j['edited_at'] != null
          ? DateTime.tryParse(j['edited_at'] as String)
          : null,
      isPinned: (j['is_pinned'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'receiver_id': receiverId,
        'read_at': readAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'reply_to_id': replyToId,
        'edited_at': editedAt?.toIso8601String(),
        'is_pinned': isPinned,
      };
}
