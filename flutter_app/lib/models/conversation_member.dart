/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `conversation_members` (gyqujitkvymlmgroovch).
class ConversationMember {
  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.createdAt,
    this.lastReadAt,
    this.role,
  });

  final String id;
  final String conversationId;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastReadAt;
  final String? role;

  factory ConversationMember.fromJson(Map<String, dynamic> j) {
    return ConversationMember(
      id: j['id'] as String? ?? '',
      conversationId: j['conversation_id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      lastReadAt: j['last_read_at'] != null
          ? DateTime.tryParse(j['last_read_at'] as String)?.toUtc()
          : null,
      role: j['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'last_read_at': lastReadAt?.toIso8601String(),
        'role': role,
      };
}
