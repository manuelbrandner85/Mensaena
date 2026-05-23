/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `post_shares` (huaqldjkgyosefzfhjnf).
class PostShare {
  const PostShare({
    required this.id,
    required this.postId,
    required this.platform,
    this.userId,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String platform;
  final String? userId;
  final DateTime? createdAt;

  factory PostShare.fromJson(Map<String, dynamic> j) {
    return PostShare(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      platform: j['platform'] as String,
      userId: j['user_id'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'platform': platform,
        'user_id': userId,
        'created_at': createdAt?.toIso8601String(),
      };
}
