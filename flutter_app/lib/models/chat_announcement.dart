/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `chat_announcements` (huaqldjkgyosefzfhjnf).
class ChatAnnouncement {
  const ChatAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.type,
    this.isActive,
    this.createdBy,
    this.createdAt,
    this.expiresAt,
    this.conversationId,
    this.authorId,
  });

  final String id;
  final String title;
  final String content;
  final String? type;
  final bool? isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? conversationId;
  final String? authorId;

  factory ChatAnnouncement.fromJson(Map<String, dynamic> j) {
    return ChatAnnouncement(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      content: j['content'] as String? ?? '',
      type: j['type'] as String?,
      isActive: j['is_active'] as bool?,
      createdBy: j['created_by'] as String?,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
      expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at'] as String) : null,
      conversationId: j['conversation_id'] as String?,
      authorId: j['author_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type,
        'is_active': isActive,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'conversation_id': conversationId,
        'author_id': authorId,
      };
}
