/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `board_comments` (huaqldjkgyosefzfhjnf).
class BoardComment {
  const BoardComment({
    required this.id,
    required this.boardPostId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String boardPostId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BoardComment.fromJson(Map<String, dynamic> j) {
    return BoardComment(
      id: j['id'] as String,
      boardPostId: j['board_post_id'] as String,
      authorId: j['author_id'] as String,
      content: j['content'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_post_id': boardPostId,
        'author_id': authorId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
