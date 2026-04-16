enum MatchStatus {
  suggested('suggested', 'Vorgeschlagen'),
  pending('pending', 'Ausstehend'),
  accepted('accepted', 'Angenommen'),
  declined('declined', 'Abgelehnt'),
  expired('expired', 'Abgelaufen'),
  completed('completed', 'Abgeschlossen'),
  cancelled('cancelled', 'Abgebrochen');

  const MatchStatus(this.value, this.label);
  final String value;
  final String label;

  static MatchStatus fromString(String value) {
    return MatchStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MatchStatus.suggested,
    );
  }
}

class Match {
  final String id;
  final String seekerPostId;
  final String offerPostId;
  final String seekerUserId;
  final String offerUserId;
  final double score;
  final Map<String, dynamic>? scoreBreakdown;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  // Joined
  final Map<String, dynamic>? seekerProfile;
  final Map<String, dynamic>? offerProfile;
  final Map<String, dynamic>? seekerPost;
  final Map<String, dynamic>? offerPost;

  const Match({
    required this.id,
    required this.seekerPostId,
    required this.offerPostId,
    required this.seekerUserId,
    required this.offerUserId,
    this.score = 0,
    this.scoreBreakdown,
    this.status = 'suggested',
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.seekerProfile,
    this.offerProfile,
    this.seekerPost,
    this.offerPost,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      seekerPostId: json['seeker_post_id'] as String,
      offerPostId: json['offer_post_id'] as String,
      seekerUserId: json['seeker_user_id'] as String,
      offerUserId: json['offer_user_id'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreBreakdown: json['score_breakdown'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'suggested',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      seekerProfile: json['seeker_profile'] as Map<String, dynamic>?,
      offerProfile: json['offer_profile'] as Map<String, dynamic>?,
      seekerPost: json['seeker_post'] as Map<String, dynamic>?,
      offerPost: json['offer_post'] as Map<String, dynamic>?,
    );
  }

  MatchStatus get matchStatus => MatchStatus.fromString(status);
  int get scorePercent => (score * 100).round();
}
