/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `user_status` (huaqldjkgyosefzfhjnf).
class UserStatus {
  const UserStatus({
    required this.userId,
    this.status,
    this.statusText,
    this.updatedAt,
  });

  final String userId;
  final String? status;
  final String? statusText;
  final DateTime? updatedAt;

  factory UserStatus.fromJson(Map<String, dynamic> j) {
    return UserStatus(
      userId: j['user_id'] as String,
      status: j['status'] as String?,
      statusText: j['status_text'] as String?,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'status': status,
        'status_text': statusText,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
