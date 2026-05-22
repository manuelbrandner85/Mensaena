class Match {
  const Match({
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
    this.declinedBy,
    this.declineReason,
    this.completedAt,
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
  final String? declinedBy;
  final String? declineReason;
  final DateTime? completedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => completedAt != null;
  bool get isAccepted =>
      (offerAccepted ?? false) && (requestAccepted ?? false);

  factory Match.fromJson(Map<String, dynamic> j) {
    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Match(
      id: j['id'] as String,
      offerPostId: j['offer_post_id'] as String? ?? '',
      requestPostId: j['request_post_id'] as String? ?? '',
      offerUserId: j['offer_user_id'] as String? ?? '',
      requestUserId: j['request_user_id'] as String? ?? '',
      matchScore: parseDouble(j['match_score']) ?? 0,
      status: j['status']?.toString() ?? 'suggested',
      offerResponded: (j['offer_responded'] as bool?) ?? false,
      requestResponded: (j['request_responded'] as bool?) ?? false,
      seenByOffer: (j['seen_by_offer'] as bool?) ?? false,
      seenByRequest: (j['seen_by_request'] as bool?) ?? false,
      expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      scoreBreakdown: (j['score_breakdown'] is Map)
          ? Map<String, dynamic>.from(j['score_breakdown'] as Map)
          : const {},
      distanceKm: parseDouble(j['distance_km']),
      offerAccepted: j['offer_accepted'] as bool?,
      requestAccepted: j['request_accepted'] as bool?,
      conversationId: j['conversation_id'] as String?,
      declinedBy: j['declined_by'] as String?,
      declineReason: j['decline_reason'] as String?,
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse(j['completed_at'] as String)
          : null,
    );
  }
}

class MatchPreferences {
  const MatchPreferences({
    required this.id,
    required this.userId,
    required this.matchingEnabled,
    required this.maxDistanceKm,
    required this.minTrustScore,
    required this.maxMatchesPerDay,
    required this.notifyOnMatch,
    required this.createdAt,
    required this.updatedAt,
    this.preferredCategories = const [],
    this.excludedCategories = const [],
    this.autoAcceptThreshold,
  });

  final String id;
  final String userId;
  final bool matchingEnabled;
  final int maxDistanceKm;
  final double minTrustScore;
  final int maxMatchesPerDay;
  final bool notifyOnMatch;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> preferredCategories;
  final List<String> excludedCategories;
  final double? autoAcceptThreshold;

  factory MatchPreferences.fromJson(Map<String, dynamic> j) {
    int parseInt(Object? v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    double parseDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    List<String> parseStrList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];

    return MatchPreferences(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      matchingEnabled: (j['matching_enabled'] as bool?) ?? true,
      maxDistanceKm: parseInt(j['max_distance_km']),
      minTrustScore: parseDouble(j['min_trust_score']),
      maxMatchesPerDay: parseInt(j['max_matches_per_day']),
      notifyOnMatch: (j['notify_on_match'] as bool?) ?? true,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
          DateTime.now(),
      preferredCategories: parseStrList(j['preferred_categories']),
      excludedCategories: parseStrList(j['excluded_categories']),
      autoAcceptThreshold: j['auto_accept_threshold'] is num
          ? (j['auto_accept_threshold'] as num).toDouble()
          : null,
    );
  }
}
