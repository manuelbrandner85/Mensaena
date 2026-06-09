/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `challenge_progress` (gyqujitkvymlmgroovch).
/// Schema: id, challenge_id, user_id, status, progress_pct, completed_at,
/// joined_at, date, checked_in, verified_by_admin.
class ChallengeProgress {
  const ChallengeProgress({
    required this.id,
    required this.challengeId,
    required this.userId,
    this.status = 'active',
    this.progressPct = 0,
    this.completedAt,
    this.joinedAt,
    this.checkedIn = false,
  });

  final String id;
  final String challengeId;
  final String userId;

  /// 'active' | 'completed' | 'abandoned'
  final String status;

  /// 0..100
  final int progressPct;
  final DateTime? completedAt;
  final DateTime? joinedAt;
  final bool checkedIn;

  /// Backward-compat: 'completed' war frueher Bool. Code der noch
  /// `.completed` nutzt bekommt jetzt completedAt != null.
  bool get completed => status == 'completed' || completedAt != null;

  /// Frueheres currentCount-Feld → wir mappen progress_pct in den 0..N-Bereich.
  /// Da DB jetzt Prozent speichert (0..100), entfaellt die fixe targetCount-Logik.
  int get currentCount => progressPct;

  factory ChallengeProgress.fromJson(Map<String, dynamic> j) {
    return ChallengeProgress(
      id: j['id'] as String,
      challengeId: j['challenge_id'] as String,
      userId: j['user_id'] as String,
      status: (j['status'] as String?) ?? 'active',
      progressPct: (j['progress_pct'] as num?)?.toInt() ?? 0,
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse(j['completed_at'] as String)?.toUtc()
          : null,
      joinedAt: j['joined_at'] != null
          ? DateTime.tryParse(j['joined_at'] as String)?.toUtc()
          : null,
      checkedIn: (j['checked_in'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'challenge_id': challengeId,
        'user_id': userId,
        'status': status,
        'progress_pct': progressPct,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
        'checked_in': checkedIn,
      };
}
