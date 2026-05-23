/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `matches` (huaqldjkgyosefzfhjnf).
/// Renamed to MatchModel to avoid collision with Dart pattern-match syntax.
class MatchModel {
  const MatchModel({
    required this.id,
    required this.offerPostId,
    required this.requestPostId,
    required this.offerUserId,
    required this.requestUserId,
    required this.matchScore,
    required this.status,
    required this.offerResponded,
    required this.requestResponded,
    required this.seenByOffer,
    required this.seenByRequest,
    required this.expiresAt,
    required this.createdAt,
    this.scoreBreakdown = const {},
    this.distanceKm,
    this.offerAccepted,
    this.requestAccepted,
    this.conversationId,
  });

  final String id;
  final String offerPostId;
  final String requestPostId;
  final String offerUserId;
  final String requestUserId;
  final double matchScore;
  final String status;
  final bool offerResponded;
  final bool requestResponded;
  final bool seenByOffer;
  final bool seenByRequest;
  final DateTime expiresAt;
  final DateTime createdAt;
  final Map<String, dynamic> scoreBreakdown;
  final double? distanceKm;
  final bool? offerAccepted;
  final bool? requestAccepted;
  final String? conversationId;

  factory MatchModel.fromJson(Map<String, dynamic> j) {
    return MatchModel(
      id: j['id'] as String,
      offerPostId: j['offer_post_id'] as String,
      requestPostId: j['request_post_id'] as String,
      offerUserId: j['offer_user_id'] as String,
      requestUserId: j['request_user_id'] as String,
      matchScore: (j['match_score'] as num?)?.toDouble() ?? 0.0,
      status: (j['status'] as String?) ?? 'pending',
      offerResponded: (j['offer_responded'] as bool?) ?? false,
      requestResponded: (j['request_responded'] as bool?) ?? false,
      seenByOffer: (j['seen_by_offer'] as bool?) ?? false,
      seenByRequest: (j['seen_by_request'] as bool?) ?? false,
      expiresAt:
          DateTime.tryParse(j['expires_at'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      scoreBreakdown: (j['score_breakdown'] is Map)
          ? Map<String, dynamic>.from(j['score_breakdown'] as Map)
          : const {},
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      offerAccepted: j['offer_accepted'] as bool?,
      requestAccepted: j['request_accepted'] as bool?,
      conversationId: j['conversation_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'offer_post_id': offerPostId,
        'request_post_id': requestPostId,
        'offer_user_id': offerUserId,
        'request_user_id': requestUserId,
        'match_score': matchScore,
        'status': status,
        'offer_responded': offerResponded,
        'request_responded': requestResponded,
        'seen_by_offer': seenByOffer,
        'seen_by_request': seenByRequest,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'score_breakdown': scoreBreakdown,
        'distance_km': distanceKm,
        'offer_accepted': offerAccepted,
        'request_accepted': requestAccepted,
        'conversation_id': conversationId,
      };
}
