/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `interaction_updates` (gyqujitkvymlmgroovch).
class InteractionUpdate {
  const InteractionUpdate({
    required this.id,
    required this.interactionId,
    required this.authorId,
    required this.updateType,
    required this.createdAt,
    this.content,
    this.oldStatus,
    this.newStatus,
  });

  final String id;
  final String interactionId;
  final String authorId;
  final String updateType;
  final DateTime createdAt;
  final String? content;
  final String? oldStatus;
  final String? newStatus;

  factory InteractionUpdate.fromJson(Map<String, dynamic> j) {
    return InteractionUpdate(
      id: j['id'] as String,
      interactionId: j['interaction_id'] as String,
      authorId: j['author_id'] as String,
      updateType: j['update_type'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      content: j['content'] as String?,
      oldStatus: j['old_status'] as String?,
      newStatus: j['new_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'interaction_id': interactionId,
        'author_id': authorId,
        'update_type': updateType,
        'created_at': createdAt.toIso8601String(),
        'content': content,
        'old_status': oldStatus,
        'new_status': newStatus,
      };
}
