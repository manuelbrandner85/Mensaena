/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `badges` (huaqldjkgyosefzfhjnf).
/// Renamed to BadgeModel to avoid collision with Flutter Material Badge.
class BadgeModel {
  const BadgeModel({
    required this.id,
    required this.name,
    required this.category,
    required this.requirementType,
    required this.requirementValue,
    required this.points,
    required this.rarity,
    required this.createdAt,
    required this.updatedAt,
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
  final DateTime updatedAt;
  final String? description;
  final String? icon;

  factory BadgeModel.fromJson(Map<String, dynamic> j) {
    return BadgeModel(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String,
      requirementType: j['requirement_type'] as String,
      requirementValue: (j['requirement_value'] as num?)?.toInt() ?? 0,
      points: (j['points'] as num?)?.toInt() ?? 0,
      rarity: j['rarity'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      description: j['description'] as String?,
      icon: j['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'requirement_type': requirementType,
        'requirement_value': requirementValue,
        'points': points,
        'rarity': rarity,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'description': description,
        'icon': icon,
      };
}
