/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `trust_ratings` (gyqujitkvymlmgroovch).
class TrustRating {
  const TrustRating({
    required this.id,
    required this.raterId,
    required this.ratedId,
    required this.score,
    required this.createdAt,
    this.comment,
    this.rating,
    this.interactionId,
    this.categories = const {},
    this.helpful,
    this.wouldRecommend,
    this.response,
    this.responseAt,
    this.editedAt,
    this.reported = false,
  });

  final String id;
  final String raterId;
  final String ratedId;
  final int score;
  final DateTime createdAt;
  final String? comment;
  final int? rating;
  final String? interactionId;
  final Map<String, dynamic> categories;
  final bool? helpful;
  final bool? wouldRecommend;
  final String? response;
  final DateTime? responseAt;
  final DateTime? editedAt;
  final bool reported;

  factory TrustRating.fromJson(Map<String, dynamic> j) {
    return TrustRating(
      id: j['id'] as String,
      raterId: j['rater_id'] as String,
      ratedId: j['rated_id'] as String,
      score: (j['score'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      comment: j['comment'] as String?,
      rating: (j['rating'] as num?)?.toInt(),
      interactionId: j['interaction_id'] as String?,
      categories: (j['categories'] is Map)
          ? Map<String, dynamic>.from(j['categories'] as Map)
          : const {},
      helpful: j['helpful'] as bool?,
      wouldRecommend: j['would_recommend'] as bool?,
      response: j['response'] as String?,
      responseAt: j['response_at'] != null
          ? DateTime.tryParse(j['response_at'] as String)
          : null,
      editedAt: j['edited_at'] != null
          ? DateTime.tryParse(j['edited_at'] as String)
          : null,
      reported: (j['reported'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rater_id': raterId,
        'rated_id': ratedId,
        'score': score,
        'created_at': createdAt.toIso8601String(),
        'comment': comment,
        'rating': rating,
        'interaction_id': interactionId,
        'categories': categories,
        'helpful': helpful,
        'would_recommend': wouldRecommend,
        'response': response,
        'response_at': responseAt?.toIso8601String(),
        'edited_at': editedAt?.toIso8601String(),
        'reported': reported,
      };
}
