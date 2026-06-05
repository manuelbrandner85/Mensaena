/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `saved_posts` (gyqujitkvymlmgroovch).
class SavedPost {
  const SavedPost({
    required this.id,
    required this.userId,
    required this.postId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String postId;
  final DateTime createdAt;

  factory SavedPost.fromJson(Map<String, dynamic> j) {
    return SavedPost(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      postId: j['post_id'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'post_id': postId,
        'created_at': createdAt.toIso8601String(),
      };
}
