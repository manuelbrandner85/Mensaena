/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `posts` (huaqldjkgyosefzfhjnf).
class Post {
  const Post({
    required this.id,
    required this.type,
    required this.title,
    required this.userId,
    required this.createdAt,
    required this.status,
    this.category,
    this.description,
    this.locationText,
    this.latitude,
    this.longitude,
    this.contactPhone,
    this.contactEmail,
    this.contactWhatsapp,
    this.urgency,
    this.updatedAt,
    this.isAnonymous = false,
    this.isRecurring = false,
    this.recurringInterval,
    this.availabilityDays = const [],
    this.availabilityStart,
    this.availabilityEnd,
    this.reactionCount = 0,
    this.mediaUrls = const [],
    this.tags = const [],
    this.privacyPhone = false,
    this.privacyEmail = false,
  });

  final String id;
  final String type;
  final String title;
  final String userId;
  final DateTime createdAt;
  final String status;
  final String? category;
  final String? description;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactWhatsapp;
  final int? urgency;
  final DateTime? updatedAt;
  final bool isAnonymous;
  final bool isRecurring;
  final String? recurringInterval;
  final List<String> availabilityDays;
  final String? availabilityStart;
  final String? availabilityEnd;
  final int reactionCount;
  final List<String> mediaUrls;
  final List<String> tags;
  final bool privacyPhone;
  final bool privacyEmail;

  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: j['id'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      userId: j['user_id'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      status: (j['status'] as String?) ?? 'open',
      category: j['category'] as String?,
      description: j['description'] as String?,
      locationText: j['location_text'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      contactPhone: j['contact_phone'] as String?,
      contactEmail: j['contact_email'] as String?,
      contactWhatsapp: j['contact_whatsapp'] as String?,
      urgency: (j['urgency'] as num?)?.toInt(),
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
      isAnonymous: (j['is_anonymous'] as bool?) ?? false,
      isRecurring: (j['is_recurring'] as bool?) ?? false,
      recurringInterval: j['recurring_interval'] as String?,
      availabilityDays: (j['availability_days'] is List)
          ? (j['availability_days'] as List).whereType<String>().toList()
          : const [],
      availabilityStart: j['availability_start'] as String?,
      availabilityEnd: j['availability_end'] as String?,
      reactionCount: (j['reaction_count'] as num?)?.toInt() ?? 0,
      mediaUrls: (j['media_urls'] is List)
          ? (j['media_urls'] as List).whereType<String>().toList()
          : const [],
      tags: (j['tags'] is List)
          ? (j['tags'] as List).whereType<String>().toList()
          : const [],
      privacyPhone: (j['privacy_phone'] as bool?) ?? false,
      privacyEmail: (j['privacy_email'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'status': status,
        'category': category,
        'description': description,
        'location_text': locationText,
        'latitude': latitude,
        'longitude': longitude,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'contact_whatsapp': contactWhatsapp,
        'urgency': urgency,
        'updated_at': updatedAt?.toIso8601String(),
        'is_anonymous': isAnonymous,
        'is_recurring': isRecurring,
        'recurring_interval': recurringInterval,
        'availability_days': availabilityDays,
        'availability_start': availabilityStart,
        'availability_end': availabilityEnd,
        'reaction_count': reactionCount,
        'media_urls': mediaUrls,
        'tags': tags,
        'privacy_phone': privacyPhone,
        'privacy_email': privacyEmail,
      };
}
