/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `organizations` (huaqldjkgyosefzfhjnf).
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

  factory Organization.fromJson(Map<String, dynamic> j) {
    return Organization(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String,
      city: j['city'] as String,
      country: j['country'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      description: j['description'] as String?,
      address: j['address'] as String?,
      zipCode: j['zip_code'] as String?,
      state: j['state'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      website: j['website'] as String?,
      openingHours: j['opening_hours'] as String?,
      services: (j['services'] is List)
          ? (j['services'] as List).whereType<String>().toList()
          : const [],
      tags: (j['tags'] is List)
          ? (j['tags'] as List).whereType<String>().toList()
          : const [],
      isVerified: (j['is_verified'] as bool?) ?? false,
      isActive: (j['is_active'] as bool?) ?? true,
      sourceUrl: j['source_url'] as String?,
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
        'opening_hours': openingHours,
        'services': services,
        'tags': tags,
        'is_verified': isVerified,
        'is_active': isActive,
        'source_url': sourceUrl,
      };
}
