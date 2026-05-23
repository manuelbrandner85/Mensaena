/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `conversations` (huaqldjkgyosefzfhjnf).
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    this.title,
    this.postId,
    this.updatedAt,
    this.isLocked,
    this.lockedBy,
    this.lockedAt,
    this.lockedReason,
    this.groupId,
  });

  final String id;
  final String type;
  final String? title;
  final DateTime createdAt;
  final String? postId;
  final DateTime? updatedAt;
  final bool? isLocked;
  final String? lockedBy;
  final DateTime? lockedAt;
  final String? lockedReason;
  final String? groupId;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    return Conversation(
      id: j['id'] as String? ?? '',
      type: j['type'] as String? ?? '',
      title: j['title'] as String?,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      postId: j['post_id'] as String?,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
      isLocked: j['is_locked'] as bool?,
      lockedBy: j['locked_by'] as String?,
      lockedAt: j['locked_at'] != null
          ? DateTime.tryParse(j['locked_at'] as String)
          : null,
      lockedReason: j['locked_reason'] as String?,
      groupId: j['group_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'post_id': postId,
        'updated_at': updatedAt?.toIso8601String(),
        'is_locked': isLocked,
        'locked_by': lockedBy,
        'locked_at': lockedAt?.toIso8601String(),
        'locked_reason': lockedReason,
        'group_id': groupId,
      };
}
