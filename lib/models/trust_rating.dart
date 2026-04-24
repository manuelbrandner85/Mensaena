class TrustRating {
  final String id;
  final String raterId;
  final String ratedId;
  final int score;
  final String? comment;
  final String? category;
  final bool? isHelpful;
  final bool? wouldRecommend;
  final DateTime createdAt;

  // Joined
  final Map<String, dynamic>? raterProfile;
  final Map<String, dynamic>? ratedProfile;

  const TrustRating({
    required this.id,
    required this.raterId,
    required this.ratedId,
    required this.score,
    this.comment,
    this.category,
    this.isHelpful,
    this.wouldRecommend,
    required this.createdAt,
    this.raterProfile,
    this.ratedProfile,
  });

  factory TrustRating.fromJson(Map<String, dynamic> json) {
    return TrustRating(
      id: json['id'] as String,
      raterId: json['rater_id'] as String,
      ratedId: json['rated_id'] as String,
      score: json['rating'] as int? ?? json['score'] as int? ?? 0,
      comment: json['comment'] as String?,
      category: json['category'] as String?,
      isHelpful: json['is_helpful'] as bool?,
      wouldRecommend: json['would_recommend'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      raterProfile: json['rater_profile'] as Map<String, dynamic>?,
      ratedProfile: json['rated_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rater_id': raterId,
      'rated_id': ratedId,
      'rating': score,
      'comment': comment,
      'category': category,
      'is_helpful': isHelpful,
      'would_recommend': wouldRecommend,
    };
  }
}

class TrustScoreData {
  final double averageScore;
  final int totalRatings;
  final int trustLevel;
  final String trustLabel;

  const TrustScoreData({
    this.averageScore = 0,
    this.totalRatings = 0,
    this.trustLevel = 0,
    this.trustLabel = 'Neu',
  });

  factory TrustScoreData.fromValues(double avg, int count) {
    final level = _calculateLevel(avg, count);
    return TrustScoreData(
      averageScore: avg,
      totalRatings: count,
      trustLevel: level,
      trustLabel: _levelLabel(level),
    );
  }

  static int _calculateLevel(double avg, int count) {
    if (count == 0) return 0;
    if (count < 3) return 1;
    if (avg >= 4.5 && count >= 10) return 5;
    if (avg >= 4.0 && count >= 5) return 4;
    if (avg >= 3.5) return 3;
    if (avg >= 3.0) return 2;
    return 1;
  }

  static String _levelLabel(int level) {
    switch (level) {
      case 0:
        return 'Neu';
      case 1:
        return 'Starter';
      case 2:
        return 'Aktiv';
      case 3:
        return 'Vertraut';
      case 4:
        return 'Erfahren';
      case 5:
        return 'Leuchtturm';
      default:
        return 'Neu';
    }
  }
}
