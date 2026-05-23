/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `challenges` (huaqldjkgyosefzfhjnf).
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.type,
    required this.targetCount,
    this.description,
    this.pointsReward,
    this.badgeId,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String type;
  final int targetCount;
  final String? description;
  final int? pointsReward;
  final String? badgeId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  factory Challenge.fromJson(Map<String, dynamic> j) {
    return Challenge(
      id: j['id'] as String,
      title: j['title'] as String,
      type: j['type'] as String,
      targetCount: (j['target_count'] as num?)?.toInt() ?? 0,
      description: j['description'] as String?,
      pointsReward: (j['points_reward'] as num?)?.toInt(),
      badgeId: j['badge_id'] as String?,
      startDate: j['start_date'] != null
          ? DateTime.tryParse(j['start_date'] as String)
          : null,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      isActive: (j['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'target_count': targetCount,
        'description': description,
        'points_reward': pointsReward,
        'badge_id': badgeId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'is_active': isActive,
      };
}
