/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `group_members` (gyqujitkvymlmgroovch).
class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.joinedAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime? joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> j) {
    return GroupMember(
      id: j['id'] as String,
      groupId: j['group_id'] as String,
      userId: j['user_id'] as String,
      role: (j['role'] as String?) ?? 'member',
      joinedAt: j['joined_at'] != null
          ? DateTime.tryParse(j['joined_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'role': role,
        'joined_at': joinedAt?.toIso8601String(),
      };
}
