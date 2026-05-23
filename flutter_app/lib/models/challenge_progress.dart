/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `challenge_progress` (huaqldjkgyosefzfhjnf).
class ChallengeProgress {
  const ChallengeProgress({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.currentCount,
    this.completed = false,
    this.completedAt,
  });

  final String id;
  final String challengeId;
  final String userId;
  final int currentCount;
  final bool completed;
  final DateTime? completedAt;

  factory ChallengeProgress.fromJson(Map<String, dynamic> j) {
    return ChallengeProgress(
      id: j['id'] as String,
      challengeId: j['challenge_id'] as String,
      userId: j['user_id'] as String,
      currentCount: (j['current_count'] as num?)?.toInt() ?? 0,
      completed: (j['completed'] as bool?) ?? false,
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse(j['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'challenge_id': challengeId,
        'user_id': userId,
        'current_count': currentCount,
        'completed': completed,
        'completed_at': completedAt?.toIso8601String(),
      };
}
