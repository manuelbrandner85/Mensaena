class FarmListing {
  final String id;
  final String name;
  final String? slug;
  final String category;
  final List<String> subcategories;
  final String? description;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, dynamic>? openingHours;
  final List<String> products;
  final List<String> services;
  final List<String> deliveryOptions;
  final String? imageUrl;
  final bool isPublic;
  final bool isVerified;
  final bool isBio;
  final bool isSeasonal;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FarmListing({
    required this.id,
    required this.name,
    this.slug,
    required this.category,
    this.subcategories = const [],
    this.description,
    this.address,
    this.postalCode,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.website,
    this.openingHours,
    this.products = const [],
    this.services = const [],
    this.deliveryOptions = const [],
    this.imageUrl,
    this.isPublic = true,
    this.isVerified = false,
    this.isBio = false,
    this.isSeasonal = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory FarmListing.fromJson(Map<String, dynamic> json) {
    return FarmListing(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      category: json['category'] as String? ?? 'hofladen',
      subcategories:
          (json['subcategories'] as List<dynamic>?)?.cast<String>() ?? [],
      description: json['description'] as String?,
      address: json['address'] as String?,
      postalCode: json['postal_code'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      products: (json['products'] as List<dynamic>?)?.cast<String>() ?? [],
      services: (json['services'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveryOptions:
          (json['delivery_options'] as List<dynamic>?)?.cast<String>() ?? [],
      imageUrl: json['image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      isBio: json['is_bio'] as bool? ?? false,
      isSeasonal: json['is_seasonal'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get countryFlag {
    switch (country?.toUpperCase()) {
      case 'DE':
        return '🇩🇪';
      case 'AT':
        return '🇦🇹';
      case 'CH':
        return '🇨🇭';
      default:
        return '🌍';
    }
  }
}
