class Challenge {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? category;
  final String difficulty;
  final int points;
  final int durationDays;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;

  // Joined
  final Map<String, dynamic>? creatorProfile;
  final int? participantCount;
  final int? userProgress;
  final int? userStreak;

  const Challenge({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.category,
    this.difficulty = 'medium',
    this.points = 10,
    this.durationDays = 7,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    required this.createdAt,
    this.creatorProfile,
    this.participantCount,
    this.userProgress,
    this.userStreak,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      points: json['points'] as int? ?? 10,
      durationDays: _calcDurationDays(json),
      imageUrl: null,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      creatorProfile: json['profiles'] as Map<String, dynamic>?,
      participantCount: json['participant_count'] as int?,
      userProgress: json['user_progress'] as int?,
      userStreak: json['user_streak'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'points': points,
      'duration_days': durationDays,
      'image_url': imageUrl,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'status': status,
    };
  }

  bool get isActive =>
      status == 'active' && endDate.isAfter(DateTime.now());
  double get progressPercent =>
      userProgress != null ? (userProgress! / durationDays).clamp(0.0, 1.0) : 0;

  static int _calcDurationDays(Map<String, dynamic> json) {
    if (json['duration_days'] != null) return json['duration_days'] as int;
    try {
      final start = DateTime.parse(json['start_date'] as String);
      final end = DateTime.parse(json['end_date'] as String);
      return end.difference(start).inDays.clamp(1, 365);
    } catch (_) {
      return 7;
    }
  }
}
