/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `groups` (gyqujitkvymlmgroovch).
import '../services/location_anonymizer.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.memberCount,
    required this.createdAt,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.isPrivate = false,
    this.postCount = 0,
    this.creatorId,
    this.maxMembers,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  final String id;
  final String name;
  final String slug;
  final String category;
  final int memberCount;
  final DateTime createdAt;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isPrivate;
  final int postCount;
  final String? creatorId;
  final int? maxMembers;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;

  /// Anonymisierte Anzeigekoordinaten (≈1 km Genauigkeit).
  double? get displayLat =>
      latitude != null ? LocationAnonymizer.lat(latitude!) : null;
  double? get displayLng =>
      longitude != null ? LocationAnonymizer.lng(longitude!) : null;

  factory Group.fromJson(Map<String, dynamic> j) {
    // BUGFIX: DB-Spalten slug + category sind nullable — vorher als
    // 'as String' required gelesen → eine einzige Row ohne slug/category
    // killte die ganze Liste. Defensive Fallback auf '' bzw. 'sonstiges'.
    return Group(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      category: j['category'] as String? ?? 'sonstiges',
      memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      description: j['description'] as String?,
      avatarUrl: (j['avatar_url'] ?? j['image_url']) as String?,
      bannerUrl: (j['banner_url'] ?? j['cover_image_url']) as String?,
      isPrivate: (j['is_private'] as bool?) ?? false,
      postCount: (j['post_count'] as num?)?.toInt() ?? 0,
      creatorId: (j['creator_id'] ?? j['created_by']) as String?,
      maxMembers: (j['max_members'] as num?)?.toInt(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      radiusKm: (j['radius_km'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'member_count': memberCount,
        'created_at': createdAt.toIso8601String(),
        'description': description,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
        'is_private': isPrivate,
        'post_count': postCount,
        'creator_id': creatorId,
        'max_members': maxMembers,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
      };
}
