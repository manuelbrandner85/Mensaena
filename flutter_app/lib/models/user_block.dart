/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `user_blocks` (gyqujitkvymlmgroovch).
class UserBlock {
  const UserBlock({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.type,
    this.createdAt,
  });

  final String id;
  final String blockerId;
  final String blockedId;
  final String type;
  final DateTime? createdAt;

  factory UserBlock.fromJson(Map<String, dynamic> j) {
    return UserBlock(
      id: j['id'] as String,
      blockerId: j['blocker_id'] as String,
      blockedId: j['blocked_id'] as String,
      type: j['type'] as String,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'blocker_id': blockerId,
        'blocked_id': blockedId,
        'type': type,
        'created_at': createdAt?.toIso8601String(),
      };
}
