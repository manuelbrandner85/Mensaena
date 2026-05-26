/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `challenges` (huaqldjkgyosefzfhjnf).
/// Schema: id, title, description, category, difficulty, points,
/// max_participants, participant_count, start_date, end_date, status,
/// creator_id, created_at, is_weekly, week_of.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.difficulty,
    this.points,
    this.maxParticipants,
    this.participantCount = 0,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.creatorId,
    this.isWeekly = false,
    this.weekOf,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;

  /// 'easy' | 'medium' | 'hard'
  final String? difficulty;
  final int? points;
  final int? maxParticipants;
  final int participantCount;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 'active' | 'archived' | 'draft'
  final String status;
  final String? creatorId;
  final bool isWeekly;
  final DateTime? weekOf;

  bool get isActive => status == 'active';

  factory Challenge.fromJson(Map<String, dynamic> j) {
    return Challenge(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      description: j['description'] as String?,
      category: j['category'] as String?,
      difficulty: j['difficulty'] as String?,
      points: (j['points'] as num?)?.toInt(),
      maxParticipants: (j['max_participants'] as num?)?.toInt(),
      participantCount:
          (j['participant_count'] as num?)?.toInt() ?? 0,
      startDate: j['start_date'] != null
          ? DateTime.tryParse(j['start_date'] as String)
          : null,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      status: j['status'] as String? ?? 'active',
      creatorId: j['creator_id'] as String?,
      isWeekly: j['is_weekly'] as bool? ?? false,
      weekOf: j['week_of'] != null
          ? DateTime.tryParse(j['week_of'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
        if (points != null) 'points': points,
        if (maxParticipants != null) 'max_participants': maxParticipants,
        'participant_count': participantCount,
        if (startDate != null) 'start_date': startDate!.toIso8601String(),
        if (endDate != null) 'end_date': endDate!.toIso8601String(),
        'status': status,
        if (creatorId != null) 'creator_id': creatorId,
        'is_weekly': isWeekly,
        if (weekOf != null)
          'week_of':
              '${weekOf!.year}-${weekOf!.month.toString().padLeft(2, '0')}-${weekOf!.day.toString().padLeft(2, '0')}',
      };
}
