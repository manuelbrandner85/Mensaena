/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `board_pins` (huaqldjkgyosefzfhjnf).
class BoardPin {
  const BoardPin({
    required this.id,
    required this.userId,
    required this.boardPostId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String boardPostId;
  final DateTime createdAt;

  factory BoardPin.fromJson(Map<String, dynamic> j) {
    return BoardPin(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      boardPostId: j['board_post_id'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'board_post_id': boardPostId,
        'created_at': createdAt.toIso8601String(),
      };
}
