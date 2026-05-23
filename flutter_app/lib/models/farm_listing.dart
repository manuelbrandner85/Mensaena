/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `farm_listings` (huaqldjkgyosefzfhjnf).
class FarmListing {
  const FarmListing({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.city,
    required this.country,
    required this.createdAt,
    required this.updatedAt,
    this.subcategories = const [],
    this.description,
    this.address,
    this.postalCode,
    this.region,
    this.state,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.website,
    this.openingHours = const {},
    this.products = const [],
    this.services = const [],
    this.deliveryOptions = const [],
    this.imageUrl,
    this.sourceUrl,
    this.sourceName,
    this.importedAt,
    this.lastVerifiedAt,
    this.isPublic,
    this.isVerified,
    this.isBio,
    this.isSeasonal,
    this.mediaUrls = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String category;
  final List<String> subcategories;
  final String? description;
  final String? address;
  final String? postalCode;
  final String city;
  final String? region;
  final String? state;
  final String country;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, dynamic> openingHours;
  final List<String> products;
  final List<String> services;
  final List<String> deliveryOptions;
  final String? imageUrl;
  final String? sourceUrl;
  final String? sourceName;
  final DateTime? importedAt;
  final DateTime? lastVerifiedAt;
  final bool? isPublic;
  final bool? isVerified;
  final bool? isBio;
  final bool? isSeasonal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> mediaUrls;

  factory FarmListing.fromJson(Map<String, dynamic> j) {
    return FarmListing(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      category: j['category'] as String? ?? '',
      subcategories: (j['subcategories'] is List)
          ? (j['subcategories'] as List).whereType<String>().toList()
          : const [],
      description: j['description'] as String?,
      address: j['address'] as String?,
      postalCode: j['postal_code'] as String?,
      city: j['city'] as String? ?? '',
      region: j['region'] as String?,
      state: j['state'] as String?,
      country: j['country'] as String? ?? '',
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      website: j['website'] as String?,
      openingHours: (j['opening_hours'] is Map)
          ? Map<String, dynamic>.from(j['opening_hours'] as Map)
          : const {},
      products: (j['products'] is List)
          ? (j['products'] as List).whereType<String>().toList()
          : const [],
      services: (j['services'] is List)
          ? (j['services'] as List).whereType<String>().toList()
          : const [],
      deliveryOptions: (j['delivery_options'] is List)
          ? (j['delivery_options'] as List).whereType<String>().toList()
          : const [],
      imageUrl: j['image_url'] as String?,
      sourceUrl: j['source_url'] as String?,
      sourceName: j['source_name'] as String?,
      importedAt: j['imported_at'] != null
          ? DateTime.tryParse(j['imported_at'] as String)
          : null,
      lastVerifiedAt: j['last_verified_at'] != null
          ? DateTime.tryParse(j['last_verified_at'] as String)
          : null,
      isPublic: j['is_public'] as bool?,
      isVerified: j['is_verified'] as bool?,
      isBio: j['is_bio'] as bool?,
      isSeasonal: j['is_seasonal'] as bool?,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      mediaUrls: (j['media_urls'] is List)
          ? (j['media_urls'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'subcategories': subcategories,
        'description': description,
        'address': address,
        'postal_code': postalCode,
        'city': city,
        'region': region,
        'state': state,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'email': email,
        'website': website,
        'opening_hours': openingHours,
        'products': products,
        'services': services,
        'delivery_options': deliveryOptions,
        'image_url': imageUrl,
        'source_url': sourceUrl,
        'source_name': sourceName,
        'imported_at': importedAt?.toIso8601String(),
        'last_verified_at': lastVerifiedAt?.toIso8601String(),
        'is_public': isPublic,
        'is_verified': isVerified,
        'is_bio': isBio,
        'is_seasonal': isSeasonal,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'media_urls': mediaUrls,
      };
}
