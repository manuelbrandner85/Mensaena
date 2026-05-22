class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.category,
    required this.requirementType,
    required this.requirementValue,
    required this.points,
    required this.rarity,
    required this.createdAt,
    this.description,
    this.icon,
  });

  final String id;
  final String name;
  final String category;
  final String requirementType;
  final int requirementValue;
  final int points;
  final String rarity;
  final DateTime createdAt;
  final String? description;
  final String? icon;

  factory BadgeDef.fromJson(Map<String, dynamic> j) {
    int parseInt(Object? v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    return BadgeDef(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      category: j['category'] as String? ?? '',
      requirementType: j['requirement_type'] as String? ?? '',
      requirementValue: parseInt(j['requirement_value']),
      points: parseInt(j['points']),
      rarity: j['rarity'] as String? ?? 'common',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      description: j['description'] as String?,
      icon: j['icon'] as String?,
    );
  }
}

class UserBadge {
  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    this.earnedAt,
    this.badge,
  });

  final String id;
  final String userId;
  final String badgeId;
  final DateTime? earnedAt;
  final BadgeDef? badge;

  factory UserBadge.fromJson(Map<String, dynamic> j) {
    final badgeData = j['badges'] as Map<String, dynamic>?;
    return UserBadge(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      badgeId: j['badge_id'] as String? ?? '',
      earnedAt: j['earned_at'] != null
          ? DateTime.tryParse(j['earned_at'] as String)
          : null,
      badge: badgeData != null ? BadgeDef.fromJson(badgeData) : null,
    );
  }
}
