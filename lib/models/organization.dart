enum OrganizationCategory {
  tierheim('tierheim', 'Tierheim', '🐾'),
  tierschutz('tierschutz', 'Tierschutz', '🦮'),
  suppenkueche('suppenkueche', 'Suppenküche', '🍲'),
  obdachlosenhilfe('obdachlosenhilfe', 'Obdachlosenhilfe', '🏠'),
  tafel('tafel', 'Tafel', '🥖'),
  kleiderkammer('kleiderkammer', 'Kleiderkammer', '👕'),
  sozialkaufhaus('sozialkaufhaus', 'Sozialkaufhaus', '🛒'),
  krisentelefon('krisentelefon', 'Krisentelefon', '📞'),
  notschlafstelle('notschlafstelle', 'Notschlafstelle', '🛏️'),
  jugend('jugend', 'Jugendhilfe', '👦'),
  senioren('senioren', 'Seniorenhilfe', '👴'),
  behinderung('behinderung', 'Behindertenhilfe', '♿'),
  sucht('sucht', 'Suchthilfe', '💊'),
  fluechtlingshilfe('fluechtlingshilfe', 'Flüchtlingshilfe', '🌍'),
  allgemein('allgemein', 'Allgemein', '🤝');

  const OrganizationCategory(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static OrganizationCategory fromString(String value) {
    return OrganizationCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrganizationCategory.allgemein,
    );
  }
}

class Organization {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? address;
  final String? zipCode;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, dynamic>? openingHours;
  final List<String> services;
  final List<String> tags;
  final bool isVerified;
  final bool isActive;
  final String? sourceUrl;
  final String? imageUrl;
  final double? averageRating;
  final int? reviewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Organization({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.address,
    this.zipCode,
    this.city,
    this.state,
    this.country,
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
    this.imageUrl,
    this.averageRating,
    this.reviewCount,
    required this.createdAt,
    this.updatedAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'allgemein',
      description: json['description'] as String?,
      address: json['address'] as String?,
      zipCode: json['zip_code'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      services: (json['services'] as List<dynamic>?)?.cast<String>() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sourceUrl: json['source_url'] as String?,
      imageUrl: json['image_url'] as String?,
      averageRating: (json['rating_avg'] as num?)?.toDouble()
          ?? (json['average_rating'] as num?)?.toDouble(),
      reviewCount: json['rating_count'] as int?
          ?? json['review_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  OrganizationCategory get orgCategory =>
      OrganizationCategory.fromString(category);

  String get fullAddress {
    final parts = <String>[];
    if (address != null) parts.add(address!);
    if (zipCode != null && city != null) {
      parts.add('$zipCode $city');
    } else if (city != null) {
      parts.add(city!);
    }
    if (country != null) parts.add(country!);
    return parts.join(', ');
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

class OrganizationReview {
  final String id;
  final String organizationId;
  final String userId;
  final int rating;
  final String? title;
  final String? comment;
  final int helpfulCount;
  final bool isFlagged;
  final String? adminResponse;
  final DateTime createdAt;

  const OrganizationReview({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.rating,
    this.title,
    this.comment,
    this.helpfulCount = 0,
    this.isFlagged = false,
    this.adminResponse,
    required this.createdAt,
  });

  factory OrganizationReview.fromJson(Map<String, dynamic> json) {
    return OrganizationReview(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int? ?? 0,
      title: json['title'] as String?,
      comment: json['content'] as String? ?? json['comment'] as String?,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      isFlagged: json['is_flagged'] as bool? ?? false,
      adminResponse: json['admin_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
