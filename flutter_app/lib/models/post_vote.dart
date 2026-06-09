/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `post_votes` (gyqujitkvymlmgroovch).
class PostVote {
  const PostVote({
    required this.id,
    required this.postId,
    required this.userId,
    required this.vote,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final int vote;
  final DateTime? createdAt;

  factory PostVote.fromJson(Map<String, dynamic> j) {
    return PostVote(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      userId: j['user_id'] as String,
      vote: (j['vote'] as num?)?.toInt() ?? 0,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'user_id': userId,
        'vote': vote,
        'created_at': createdAt?.toIso8601String(),
      };
}
