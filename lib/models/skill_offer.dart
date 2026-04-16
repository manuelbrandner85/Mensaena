class SkillOffer {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? skillCategory;
  final String? level;
  final bool isFree;
  final double? hourlyRate;
  final String? currency;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final int? maxHoursWeek;
  final String? locationType;
  final String? city;
  final String? country;
  final List<String> tags;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? profile;

  const SkillOffer({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.skillCategory,
    this.level,
    this.isFree = true,
    this.hourlyRate,
    this.currency,
    this.availableFrom,
    this.availableUntil,
    this.maxHoursWeek,
    this.locationType,
    this.city,
    this.country,
    this.tags = const [],
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
    this.profile,
  });

  factory SkillOffer.fromJson(Map<String, dynamic> json) {
    return SkillOffer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      skillCategory: json['skill_category'] as String?,
      level: json['level'] as String?,
      isFree: json['is_free'] as bool? ?? true,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from'] as String)
          : null,
      availableUntil: json['available_until'] != null
          ? DateTime.parse(json['available_until'] as String)
          : null,
      maxHoursWeek: json['max_hours_week'] as int?,
      locationType: json['location_type'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'skill_category': skillCategory,
      'level': level,
      'is_free': isFree,
      'hourly_rate': hourlyRate,
      'currency': currency,
      'max_hours_week': maxHoursWeek,
      'location_type': locationType,
      'city': city,
      'country': country,
      'tags': tags,
      'status': status,
    };
  }
}
