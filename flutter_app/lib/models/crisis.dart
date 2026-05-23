/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `crises` (huaqldjkgyosefzfhjnf).
class Crisis {
  const Crisis({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    this.locationText,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.affectedCount,
    this.imageUrls = const [],
    this.contactPhone,
    this.contactName,
    this.isAnonymous,
    this.isVerified,
    this.verifiedBy,
    this.verifiedAt,
    this.resolvedAt,
    this.resolvedBy,
    this.falseAlarmBy,
    this.helperCount,
    this.neededHelpers,
    this.neededSkills = const [],
    this.neededResources = const [],
    this.createdAt,
    this.updatedAt,
    this.resolvedImageUrl,
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String status;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final int? affectedCount;
  final List<String> imageUrls;
  final String? contactPhone;
  final String? contactName;
  final bool? isAnonymous;
  final bool? isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? falseAlarmBy;
  final int? helperCount;
  final int? neededHelpers;
  final List<String> neededSkills;
  final List<String> neededResources;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? resolvedImageUrl;

  factory Crisis.fromJson(Map<String, dynamic> j) {
    return Crisis(
      id: j['id'] as String? ?? '',
      creatorId: j['creator_id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      category: j['category'] as String? ?? '',
      urgency: j['urgency'] as String? ?? '',
      status: j['status'] as String? ?? '',
      locationText: j['location_text'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      radiusKm: (j['radius_km'] as num?)?.toDouble(),
      affectedCount: (j['affected_count'] as num?)?.toInt(),
      imageUrls: (j['image_urls'] is List)
          ? (j['image_urls'] as List).whereType<String>().toList()
          : const [],
      contactPhone: j['contact_phone'] as String?,
      contactName: j['contact_name'] as String?,
      isAnonymous: j['is_anonymous'] as bool?,
      isVerified: j['is_verified'] as bool?,
      verifiedBy: j['verified_by'] as String?,
      verifiedAt: j['verified_at'] != null ? DateTime.tryParse(j['verified_at'] as String) : null,
      resolvedAt: j['resolved_at'] != null ? DateTime.tryParse(j['resolved_at'] as String) : null,
      resolvedBy: j['resolved_by'] as String?,
      falseAlarmBy: j['false_alarm_by'] as String?,
      helperCount: (j['helper_count'] as num?)?.toInt(),
      neededHelpers: (j['needed_helpers'] as num?)?.toInt(),
      neededSkills: (j['needed_skills'] is List)
          ? (j['needed_skills'] as List).whereType<String>().toList()
          : const [],
      neededResources: (j['needed_resources'] is List)
          ? (j['needed_resources'] as List).whereType<String>().toList()
          : const [],
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'] as String) : null,
      resolvedImageUrl: j['resolved_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator_id': creatorId,
        'title': title,
        'description': description,
        'category': category,
        'urgency': urgency,
        'status': status,
        'location_text': locationText,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'affected_count': affectedCount,
        'image_urls': imageUrls,
        'contact_phone': contactPhone,
        'contact_name': contactName,
        'is_anonymous': isAnonymous,
        'is_verified': isVerified,
        'verified_by': verifiedBy,
        'verified_at': verifiedAt?.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'resolved_by': resolvedBy,
        'false_alarm_by': falseAlarmBy,
        'helper_count': helperCount,
        'needed_helpers': neededHelpers,
        'needed_skills': neededSkills,
        'needed_resources': neededResources,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'resolved_image_url': resolvedImageUrl,
      };
}
