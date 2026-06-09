/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `post_comments` (gyqujitkvymlmgroovch).
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
    this.isEdited = false,
    this.deletedAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentId;
  final bool isEdited;
  final DateTime? deletedAt;

  factory PostComment.fromJson(Map<String, dynamic> j) {
    return PostComment(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      userId: j['user_id'] as String,
      content: j['content'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)?.toUtc()
          : null,
      parentId: j['parent_id'] as String?,
      isEdited: (j['is_edited'] as bool?) ?? false,
      deletedAt: j['deleted_at'] != null
          ? DateTime.tryParse(j['deleted_at'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'parent_id': parentId,
        'is_edited': isEdited,
        'deleted_at': deletedAt?.toIso8601String(),
      };
}
