/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `interactions` (huaqldjkgyosefzfhjnf).
class Interaction {
  const Interaction({
    required this.id,
    required this.postId,
    required this.helperId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.message,
    this.helpedId,
    this.matchId,
    this.responseMessage,
    this.cancelReason,
    this.completedBy,
    this.completionNotes,
    this.conversationId,
    this.completedAt,
    this.ratingRequested = false,
    this.helperRated = false,
    this.helpedRated = false,
  });

  final String id;
  final String postId;
  final String helperId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? message;
  final String? helpedId;
  final String? matchId;
  final String? responseMessage;
  final String? cancelReason;
  final String? completedBy;
  final String? completionNotes;
  final String? conversationId;
  final DateTime? completedAt;
  final bool ratingRequested;
  final bool helperRated;
  final bool helpedRated;

  factory Interaction.fromJson(Map<String, dynamic> j) {
    return Interaction(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      helperId: j['helper_id'] as String,
      status: j['status'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      message: j['message'] as String?,
      helpedId: j['helped_id'] as String?,
      matchId: j['match_id'] as String?,
      responseMessage: j['response_message'] as String?,
      cancelReason: j['cancel_reason'] as String?,
      completedBy: j['completed_by'] as String?,
      completionNotes: j['completion_notes'] as String?,
      conversationId: j['conversation_id'] as String?,
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse(j['completed_at'] as String)
          : null,
      ratingRequested: (j['rating_requested'] as bool?) ?? false,
      helperRated: (j['helper_rated'] as bool?) ?? false,
      helpedRated: (j['helped_rated'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'helper_id': helperId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'message': message,
        'helped_id': helpedId,
        'match_id': matchId,
        'response_message': responseMessage,
        'cancel_reason': cancelReason,
        'completed_by': completedBy,
        'completion_notes': completionNotes,
        'conversation_id': conversationId,
        'completed_at': completedAt?.toIso8601String(),
        'rating_requested': ratingRequested,
        'helper_rated': helperRated,
        'helped_rated': helpedRated,
      };
}
