/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `organizations` (gyqujitkvymlmgroovch).
///
/// Hinweis: `openingHours` (String) bleibt fuer Legacy-Daten/Anzeige,
/// `openingHoursJson` (Map<String, dynamic>) ist die neue JSONB-Quelle.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.country,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.address,
    this.zipCode,
    this.state,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.website,
    this.openingHours,
    this.services = const [],
    this.tags = const [],
    this.isVerified = false,
    this.isActive = true,
    this.sourceUrl,
    // Neue Felder (Phase O1)
    this.logoUrl,
    this.coverImageUrl,
    this.shortDescription,
    this.fax,
    this.openingHoursJson,
    this.openingHoursText,
    this.isEmergency = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.ratingSum = 0,
    this.targetGroups = const [],
    this.languages = const [],
    this.accessibility = const {},
    this.slug,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String category;
  final String city;
  final String country;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? address;
  final String? zipCode;
  final String? state;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? website;
  final String? openingHours;
  final List<String> services;
  final List<String> tags;
  final bool isVerified;
  final bool isActive;
  final String? sourceUrl;

  // ── Phase O1 ──────────────────────────────────────────────────────
  final String? logoUrl;
  final String? coverImageUrl;
  final String? shortDescription;
  final String? fax;
  final Map<String, dynamic>? openingHoursJson;
  final String? openingHoursText;
  final bool isEmergency;
  final double ratingAvg;
  final int ratingCount;
  final int ratingSum;
  final List<String> targetGroups;
  final List<String> languages;
  final Map<String, dynamic> accessibility;
  final String? slug;
  final double? distanceKm;

  factory Organization.fromJson(Map<String, dynamic> j) {
    // opening_hours kann Map (JSONB) ODER String (legacy) sein.
    final rawOpening = j['opening_hours'];
    String? openingHoursStr;
    Map<String, dynamic>? openingHoursMap;
    if (rawOpening is String) {
      openingHoursStr = rawOpening;
    } else if (rawOpening is Map) {
      openingHoursMap = Map<String, dynamic>.from(rawOpening);
    }

    List<String> stringList(dynamic v) {
      if (v is List) return v.whereType<String>().toList();
      return const [];
    }

    return Organization(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String,
      city: (j['city'] as String?) ?? '',
      country: (j['country'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      description: j['description'] as String?,
      address: j['address'] as String?,
      zipCode: j['zip_code'] as String?,
      state: j['state'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      website: j['website'] as String?,
      openingHours: openingHoursStr,
      openingHoursJson: openingHoursMap,
      openingHoursText: j['opening_hours_text'] as String?,
      services: stringList(j['services']),
      tags: stringList(j['tags']),
      isVerified: (j['is_verified'] as bool?) ?? false,
      isActive: (j['is_active'] as bool?) ?? true,
      sourceUrl: j['source_url'] as String?,
      // Neue Felder
      logoUrl: j['logo_url'] as String?,
      coverImageUrl: j['cover_image_url'] as String?,
      shortDescription: j['short_description'] as String?,
      fax: j['fax'] as String?,
      isEmergency: (j['is_emergency'] as bool?) ?? false,
      ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
      ratingSum: (j['rating_sum'] as num?)?.toInt() ?? 0,
      targetGroups: stringList(j['target_groups']),
      languages: stringList(j['languages']),
      accessibility: (j['accessibility'] is Map)
          ? Map<String, dynamic>.from(j['accessibility'] as Map)
          : const {},
      slug: j['slug'] as String?,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'city': city,
        'country': country,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'description': description,
        'address': address,
        'zip_code': zipCode,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'email': email,
        'website': website,
        'opening_hours': openingHoursJson ?? openingHours,
        'opening_hours_text': openingHoursText,
        'services': services,
        'tags': tags,
        'is_verified': isVerified,
        'is_active': isActive,
        'source_url': sourceUrl,
        'logo_url': logoUrl,
        'cover_image_url': coverImageUrl,
        'short_description': shortDescription,
        'fax': fax,
        'is_emergency': isEmergency,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'rating_sum': ratingSum,
        'target_groups': targetGroups,
        'languages': languages,
        'accessibility': accessibility,
        'slug': slug,
      };
}
