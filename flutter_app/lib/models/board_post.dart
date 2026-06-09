/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `board_posts` (gyqujitkvymlmgroovch).
class BoardPost {
  const BoardPost({
    required this.id,
    required this.authorId,
    required this.content,
    required this.category,
    required this.color,
    required this.pinned,
    required this.pinCount,
    required this.commentCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.contactInfo,
    this.expiresAt,
    this.latitude,
    this.longitude,
    this.regionId,
    this.mediaUrls = const [],
  });

  final String id;
  final String authorId;
  final String content;
  final String category;
  final String color;
  final bool pinned;
  final int pinCount;
  final int commentCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final String? contactInfo;
  final DateTime? expiresAt;
  final double? latitude;
  final double? longitude;
  final String? regionId;
  final List<String> mediaUrls;

  factory BoardPost.fromJson(Map<String, dynamic> j) {
    return BoardPost(
      id: j['id'] as String,
      authorId: j['author_id'] as String,
      content: j['content'] as String,
      category: j['category'] as String,
      color: j['color'] as String,
      pinned: (j['pinned'] as bool?) ?? false,
      pinCount: (j['pin_count'] as num?)?.toInt() ?? 0,
      commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
      status: (j['status'] as String?) ?? 'active',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      imageUrl: j['image_url'] as String?,
      contactInfo: j['contact_info'] as String?,
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'] as String)?.toUtc()
          : null,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      regionId: j['region_id'] as String?,
      mediaUrls: (j['media_urls'] is List)
          ? (j['media_urls'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'content': content,
        'category': category,
        'color': color,
        'pinned': pinned,
        'pin_count': pinCount,
        'comment_count': commentCount,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'image_url': imageUrl,
        'contact_info': contactInfo,
        'expires_at': expiresAt?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'region_id': regionId,
        'media_urls': mediaUrls,
      };
}
