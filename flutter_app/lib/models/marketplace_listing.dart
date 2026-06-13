/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `marketplace_listings` (gyqujitkvymlmgroovch).
import '../services/location_anonymizer.dart';

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.listingType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.condition,
    this.images = const [],
    this.thumbnailUrl,
    this.locationText,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.reservedFor,
    this.tags = const [],
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.expiresAt,
    this.price,
    this.priceType,
    this.conditionState,
    this.sellerId,
    this.imageUrls = const [],
    this.reservedUntil,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final String listingType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? condition;
  final List<String> images;
  final String? thumbnailUrl;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final String? reservedFor;
  final List<String> tags;
  final int viewCount;
  final int favoriteCount;
  final DateTime? expiresAt;
  final double? price;
  final String? priceType;
  final String? conditionState;
  final String? sellerId;
  final List<String> imageUrls;
  final DateTime? reservedUntil;

  /// Anonymisierte Anzeigekoordinaten (≈1 km Genauigkeit).
  double? get displayLat =>
      latitude != null ? LocationAnonymizer.lat(latitude!) : null;
  double? get displayLng =>
      longitude != null ? LocationAnonymizer.lng(longitude!) : null;

  factory MarketplaceListing.fromJson(Map<String, dynamic> j) {
    return MarketplaceListing(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      category: j['category'] as String,
      listingType: j['listing_type'] as String,
      status: j['status'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      condition: j['condition'] as String?,
      images: (j['images'] is List)
          ? (j['images'] as List).whereType<String>().toList()
          : const [],
      thumbnailUrl: j['thumbnail_url'] as String?,
      locationText: j['location_text'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      radiusKm: (j['radius_km'] as num?)?.toInt(),
      reservedFor: j['reserved_for'] as String?,
      tags: (j['tags'] is List)
          ? (j['tags'] as List).whereType<String>().toList()
          : const [],
      viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (j['favorite_count'] as num?)?.toInt() ?? 0,
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'] as String)?.toUtc()
          : null,
      price: (j['price'] as num?)?.toDouble(),
      priceType: j['price_type'] as String?,
      conditionState: j['condition_state'] as String?,
      sellerId: j['seller_id'] as String?,
      imageUrls: (j['image_urls'] is List)
          ? (j['image_urls'] as List).whereType<String>().toList()
          : const [],
      reservedUntil: j['reserved_until'] != null
          ? DateTime.tryParse(j['reserved_until'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'listing_type': listingType,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'condition': condition,
        'images': images,
        'thumbnail_url': thumbnailUrl,
        'location_text': locationText,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'reserved_for': reservedFor,
        'tags': tags,
        'view_count': viewCount,
        'favorite_count': favoriteCount,
        'expires_at': expiresAt?.toIso8601String(),
        'price': price,
        'price_type': priceType,
        'condition_state': conditionState,
        'seller_id': sellerId,
        'image_urls': imageUrls,
        'reserved_until': reservedUntil?.toIso8601String(),
      };
}
