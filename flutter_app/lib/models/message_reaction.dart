/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `message_reactions` (gyqujitkvymlmgroovch).
class MessageReaction {
  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime? createdAt;

  factory MessageReaction.fromJson(Map<String, dynamic> j) {
    return MessageReaction(
      id: j['id'] as String,
      messageId: j['message_id'] as String,
      userId: j['user_id'] as String,
      emoji: j['emoji'] as String,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
        'created_at': createdAt?.toIso8601String(),
      };
}
