/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `user_badges` (huaqldjkgyosefzfhjnf).
class UserBadge {
  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    this.earnedAt,
  });

  final String id;
  final String userId;
  final String badgeId;
  final DateTime? earnedAt;

  factory UserBadge.fromJson(Map<String, dynamic> j) {
    return UserBadge(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      badgeId: j['badge_id'] as String,
      earnedAt: j['earned_at'] != null
          ? DateTime.tryParse(j['earned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'badge_id': badgeId,
        'earned_at': earnedAt?.toIso8601String(),
      };
}
