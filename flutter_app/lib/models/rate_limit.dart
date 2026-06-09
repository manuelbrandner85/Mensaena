/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `rate_limits` (gyqujitkvymlmgroovch).
class RateLimit {
  const RateLimit({
    required this.id,
    required this.userId,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String action;
  final DateTime createdAt;

  factory RateLimit.fromJson(Map<String, dynamic> j) {
    return RateLimit(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      action: j['action'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'action': action,
        'created_at': createdAt.toIso8601String(),
      };
}
