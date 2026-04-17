class MarketplaceListing {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? category;
  final String listingType; // 'offer' or 'request'
  final String? condition;
  final List<String> images;
  final String? thumbnailUrl;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String status;
  final String? reservedFor;
  final List<String> tags;
  final int viewCount;
  final int favoriteCount;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? price;
  final String? priceType;
  final String? conditionState;
  final String? sellerId;
  final List<String> imageUrls;

  // Joined
  final bool isFavorited;

  const MarketplaceListing({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    this.listingType = 'offer',
    this.condition,
    this.images = const [],
    this.thumbnailUrl,
    this.locationText,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.status = 'active',
    this.reservedFor,
    this.tags = const [],
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
    this.price,
    this.priceType,
    this.conditionState,
    this.sellerId,
    this.imageUrls = const [],
    this.isFavorited = false,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json,
      {bool isFavorited = false}) {
    return MarketplaceListing(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      listingType: json['listing_type'] as String? ?? 'offer',
      condition: json['condition'] as String?,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      thumbnailUrl: json['thumbnail_url'] as String?,
      locationText: json['location_text'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusKm: (json['radius_km'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      reservedFor: json['reserved_for'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      price: (json['price'] as num?)?.toDouble(),
      priceType: json['price_type'] as String?,
      conditionState: json['condition_state'] as String?,
      sellerId: json['seller_id'] as String?,
      imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorited: isFavorited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'listing_type': listingType,
      'condition': condition,
      'images': images,
      'thumbnail_url': thumbnailUrl,
      'location_text': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'status': status,
      'tags': tags,
      'price': price,
      'price_type': priceType,
      'condition_state': conditionState,
      'image_urls': imageUrls,
    };
  }

  String get displayPrice {
    if (price == null || price == 0) return 'Kostenlos';
    final formatted = price!.toStringAsFixed(price! == price!.roundToDouble() ? 0 : 2);
    switch (priceType) {
      case 'vb':
        return '$formatted \u20AC VB';
      case 'fixed':
        return '$formatted \u20AC';
      default:
        return '$formatted \u20AC';
    }
  }

  String get displayCondition {
    switch (conditionState ?? condition) {
      case 'new':
        return 'Neu';
      case 'like_new':
        return 'Wie neu';
      case 'good':
        return 'Gut';
      case 'used':
        return 'Gebraucht';
      case 'defective':
        return 'Defekt';
      default:
        return '';
    }
  }

  String get displayListingType {
    switch (listingType) {
      case 'offer':
        return 'Angebot';
      case 'request':
        return 'Gesuch';
      default:
        return listingType;
    }
  }

  String? get firstImage {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (imageUrls.isNotEmpty) return imageUrls.first;
    if (images.isNotEmpty) return images.first;
    return null;
  }
}
