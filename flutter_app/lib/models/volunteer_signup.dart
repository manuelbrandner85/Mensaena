/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `volunteer_signups` (huaqldjkgyosefzfhjnf).
class VolunteerSignup {
  const VolunteerSignup({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
    this.message,
    this.status,
    this.respondedAt,
  });

  final String id;
  final String postId;
  final String userId;
  final DateTime createdAt;
  final String? message;
  final String? status;
  final DateTime? respondedAt;

  factory VolunteerSignup.fromJson(Map<String, dynamic> j) {
    return VolunteerSignup(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      userId: j['user_id'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      message: j['message'] as String?,
      status: j['status'] as String?,
      respondedAt: j['responded_at'] != null
          ? DateTime.tryParse(j['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'message': message,
        'status': status,
        'responded_at': respondedAt?.toIso8601String(),
      };
}
