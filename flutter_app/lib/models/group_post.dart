/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `group_posts` (gyqujitkvymlmgroovch).
class GroupPost {
  const GroupPost({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.content,
    this.imageUrl,
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String content;
  final String? imageUrl;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GroupPost.fromJson(Map<String, dynamic> j) {
    return GroupPost(
      id: j['id'] as String,
      groupId: j['group_id'] as String,
      userId: j['user_id'] as String,
      content: j['content'] as String,
      imageUrl: j['image_url'] as String?,
      isPinned: (j['is_pinned'] as bool?) ?? false,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'content': content,
        'image_url': imageUrl,
        'is_pinned': isPinned,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
