/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `chat_banned_users` (gyqujitkvymlmgroovch).
class ChatBannedUser {
  const ChatBannedUser({
    required this.id,
    required this.userId,
    required this.bannedBy,
    this.reason,
    this.bannedAt,
    this.expiresAt,
    this.channelId,
  });

  final String id;
  final String userId;
  final String bannedBy;
  final String? reason;
  final DateTime? bannedAt;
  final DateTime? expiresAt;
  final String? channelId;

  factory ChatBannedUser.fromJson(Map<String, dynamic> j) {
    return ChatBannedUser(
      id: j['id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      bannedBy: j['banned_by'] as String? ?? '',
      reason: j['reason'] as String?,
      bannedAt: j['banned_at'] != null
          ? DateTime.tryParse(j['banned_at'] as String)
          : null,
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'] as String)
          : null,
      channelId: j['channel_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'banned_by': bannedBy,
        'reason': reason,
        'banned_at': bannedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'channel_id': channelId,
      };
}
