/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Flatter Mapping der `get_my_matches` RPC-Response (huaqldjkgyosefzfhjnf).
/// Enthaelt eingebettete Post-/User-Infos fuer die Listen-Anzeige.
class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.offerUserId,
    required this.requestUserId,
    required this.matchScore,
    required this.status,
    required this.offerAccepted,
    required this.requestAccepted,
    required this.offerPost,
    required this.requestPost,
    required this.offerUser,
    required this.requestUser,
    required this.createdAt,
    this.distanceKm,
    this.conversationId,
    this.seenByOffer = false,
    this.seenByRequest = false,
  });

  final String id;
  final String offerUserId;
  final String requestUserId;
  final double matchScore;
  final String status;
  final bool? offerAccepted;
  final bool? requestAccepted;
  final MatchPostInfo offerPost;
  final MatchPostInfo requestPost;
  final MatchUserInfo offerUser;
  final MatchUserInfo requestUser;
  final DateTime createdAt;
  final double? distanceKm;
  final String? conversationId;
  final bool seenByOffer;
  final bool seenByRequest;

  factory MatchSummary.fromRpcRow(Map<String, dynamic> r) {
    return MatchSummary(
      id: r['id'] as String,
      offerUserId: r['offer_user_id'] as String? ?? '',
      requestUserId: r['request_user_id'] as String? ?? '',
      matchScore: (r['match_score'] as num?)?.toDouble() ?? 0.0,
      status: (r['status'] as String?) ?? 'pending',
      offerAccepted: r['offer_accepted'] as bool?,
      requestAccepted: r['request_accepted'] as bool?,
      offerPost: MatchPostInfo(
        id: r['offer_post_id'] as String? ?? '',
        title: r['offer_post_title'] as String? ?? 'Untitled',
        type: r['offer_post_type'] as String? ?? '',
        category: r['offer_post_category'] as String?,
        description: r['offer_post_description'] as String?,
        location: r['offer_post_location'] as String?,
        urgency: r['offer_post_urgency'] as String?,
      ),
      requestPost: MatchPostInfo(
        id: r['request_post_id'] as String? ?? '',
        title: r['request_post_title'] as String? ?? 'Untitled',
        type: r['request_post_type'] as String? ?? '',
        category: r['request_post_category'] as String?,
        description: r['request_post_description'] as String?,
        location: r['request_post_location'] as String?,
        urgency: r['request_post_urgency'] as String?,
      ),
      offerUser: MatchUserInfo(
        id: r['offer_user_id'] as String? ?? '',
        name: r['offer_user_name'] as String?,
        avatarUrl: r['offer_user_avatar'] as String?,
      ),
      requestUser: MatchUserInfo(
        id: r['request_user_id'] as String? ?? '',
        name: r['request_user_name'] as String?,
        avatarUrl: r['request_user_avatar'] as String?,
      ),
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
          DateTime.now(),
      distanceKm: (r['distance_km'] as num?)?.toDouble(),
      conversationId: r['conversation_id'] as String?,
      seenByOffer: (r['seen_by_offer'] as bool?) ?? false,
      seenByRequest: (r['seen_by_request'] as bool?) ?? false,
    );
  }
}

class MatchPostInfo {
  const MatchPostInfo({
    required this.id,
    required this.title,
    required this.type,
    this.category,
    this.description,
    this.location,
    this.urgency,
  });

  final String id;
  final String title;
  final String type;
  final String? category;
  final String? description;
  final String? location;
  final String? urgency;
}

class MatchUserInfo {
  const MatchUserInfo({
    required this.id,
    this.name,
    this.avatarUrl,
  });

  final String id;
  final String? name;
  final String? avatarUrl;
}
