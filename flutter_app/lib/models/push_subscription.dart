/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `push_subscriptions` (gyqujitkvymlmgroovch).
class PushSubscription {
  const PushSubscription({
    required this.id,
    required this.userId,
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    required this.active,
    required this.updatedAt,
    this.userAgent,
    this.createdAt,
    this.lastUsed,
    this.deviceType,
  });

  final String id;
  final String userId;
  final String endpoint;
  final String p256dh;
  final String auth;
  final bool active;
  final DateTime updatedAt;
  final String? userAgent;
  final DateTime? createdAt;
  final DateTime? lastUsed;
  final String? deviceType;

  factory PushSubscription.fromJson(Map<String, dynamic> j) {
    return PushSubscription(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      endpoint: j['endpoint'] as String,
      p256dh: j['p256dh'] as String,
      auth: j['auth'] as String,
      active: (j['active'] as bool?) ?? true,
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      userAgent: j['user_agent'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      lastUsed: j['last_used'] != null
          ? DateTime.tryParse(j['last_used'] as String)
          : null,
      deviceType: j['device_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'endpoint': endpoint,
        'p256dh': p256dh,
        'auth': auth,
        'active': active,
        'updated_at': updatedAt.toIso8601String(),
        'user_agent': userAgent,
        'created_at': createdAt?.toIso8601String(),
        'last_used': lastUsed?.toIso8601String(),
        'device_type': deviceType,
      };
}
