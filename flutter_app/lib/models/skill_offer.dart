/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `skill_offers` (huaqldjkgyosefzfhjnf).
class SkillOffer {
  const SkillOffer({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.skillCategory,
    this.level,
    this.isFree = true,
    this.hourlyRate,
    this.currency,
    this.availableFrom,
    this.availableUntil,
    this.locationLat,
    this.locationLng,
    this.locationAddress,
    this.radiusKm,
    this.isOnline = false,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? skillCategory;
  final String? level;
  final bool isFree;
  final double? hourlyRate;
  final String? currency;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final double? locationLat;
  final double? locationLng;
  final String? locationAddress;
  final int? radiusKm;
  final bool isOnline;
  final bool isActive;

  factory SkillOffer.fromJson(Map<String, dynamic> j) {
    return SkillOffer(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      skillCategory: j['skill_category'] as String?,
      level: j['level'] as String?,
      isFree: (j['is_free'] as bool?) ?? true,
      hourlyRate: (j['hourly_rate'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      availableFrom: j['available_from'] != null
          ? DateTime.tryParse(j['available_from'] as String)
          : null,
      availableUntil: j['available_until'] != null
          ? DateTime.tryParse(j['available_until'] as String)
          : null,
      locationLat: (j['location_lat'] as num?)?.toDouble(),
      locationLng: (j['location_lng'] as num?)?.toDouble(),
      locationAddress: j['location_address'] as String?,
      radiusKm: (j['radius_km'] as num?)?.toInt(),
      isOnline: (j['is_online'] as bool?) ?? false,
      isActive: (j['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'skill_category': skillCategory,
        'level': level,
        'is_free': isFree,
        'hourly_rate': hourlyRate,
        'currency': currency,
        'available_from': availableFrom?.toIso8601String(),
        'available_until': availableUntil?.toIso8601String(),
        'location_lat': locationLat,
        'location_lng': locationLng,
        'location_address': locationAddress,
        'radius_km': radiusKm,
        'is_online': isOnline,
        'is_active': isActive,
      };
}
