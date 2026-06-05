// SKILL: mensaena-architektur + flutter-implement-json-serialization
// Spiegel der Supabase-Tabelle `posts` (gyqujitkvymlmgroovch).
import 'post_intent.dart';

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.title,
    required this.userId,
    this.postIntent = PostIntent.general,
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
    this.imageUrls = const [],
    this.tags = const [],
    this.privacyPhone = false,
    this.privacyEmail = false,
    this.likeCount,
    this.commentCount,
    this.saveCount,
    this.scheduledAt,
    this.expiresAt,
  });

  final String id;
  final String type;
  final PostIntent postIntent;
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
  /// urgency-Spalte ist TEXT in der DB mit Werten 'low' | 'medium' | 'high' |
  /// 'critical'. Vorher castete der Code auf int → TypeError fuer jeden
  /// Post mit gesetztem urgency → die gesamte map-Iteration brach ab →
  /// User sah leere Beitragsliste. Helper-Methoden (urgencyLevel,
  /// urgencyEmoji, urgencyLabel) siehe PostUrgencyX-Extension am Datei-Ende.
  final String? urgency;
  final DateTime? updatedAt;
  final bool isAnonymous;
  final bool isRecurring;
  final String? recurringInterval;
  final List<String> availabilityDays;
  final String? availabilityStart;
  final String? availabilityEnd;
  final int reactionCount;
  final List<String> mediaUrls;
  final List<String> imageUrls;

  /// All image-like URLs from both columns (image_urls + mediaUrls).
  /// Used for carousel rendering.
  List<String> get allImageUrls => [...imageUrls, ...mediaUrls];
  final List<String> tags;
  final bool privacyPhone;
  final bool privacyEmail;
  final int? likeCount;
  final int? commentCount;
  final int? saveCount;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;

  bool get isScheduled =>
      scheduledAt != null && scheduledAt!.isAfter(DateTime.now());
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: j['id'] as String,
      type: j['type'] as String,
      postIntent: PostIntent.fromString(j['post_intent'] as String?),
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
      // Defensiv: toString() handhabt String UND num UND null ohne Cast.
      // Spalte ist TEXT in der DB — frueherer Code crashte mit TypeError.
      urgency: j['urgency']?.toString(),
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
      likeCount: (j['like_count'] as num?)?.toInt(),
      commentCount: (j['comment_count'] as num?)?.toInt(),
      saveCount: (j['save_count'] as num?)?.toInt(),
      imageUrls: (j['image_urls'] is List)
          ? (j['image_urls'] as List).whereType<String>().toList()
          : const [],
      mediaUrls: (j['media_urls'] is List)
          ? (j['media_urls'] as List).whereType<String>().toList()
          : const [],
      tags: (j['tags'] is List)
          ? (j['tags'] as List).whereType<String>().toList()
          : const [],
      privacyPhone: (j['privacy_phone'] as bool?) ?? false,
      privacyEmail: (j['privacy_email'] as bool?) ?? false,
      scheduledAt: j['scheduled_at'] != null
          ? DateTime.tryParse(j['scheduled_at'] as String)
          : null,
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'post_intent': postIntent.value,
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
        'image_urls': imageUrls,
        'media_urls': mediaUrls,
        'tags': tags,
        'privacy_phone': privacyPhone,
        'privacy_email': privacyEmail,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      };
}

/// Helper-Methoden fuer urgency. Bleibt Extension damit Post selbst
/// immutable + lean bleibt, und das Mapping zwischen DB-Werten
/// ('low','medium','high','critical') und UI-Darstellung an einer
/// Stelle steht.
extension PostUrgencyX on Post {
  /// Numerischer Level fuer Sortierung — hoeher = dringender.
  /// 0 = kein urgency gesetzt.
  int get urgencyLevel {
    switch (urgency) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  /// Lokalisierbares Label fuer die UI (DE-Default — Caller kann via
  /// .tr()-Key uebersetzen falls noetig).
  String get urgencyLabel {
    switch (urgency) {
      case 'critical':
        return 'KRITISCH';
      case 'high':
        return 'HOCH';
      case 'medium':
        return 'MITTEL';
      case 'low':
        return 'NIEDRIG';
      default:
        return '';
    }
  }

  /// Badge-Emoji fuer kompakte Darstellung.
  String get urgencyEmoji {
    switch (urgency) {
      case 'critical':
        return '🔴';
      case 'high':
        return '🟠';
      case 'medium':
        return '🟡';
      case 'low':
        return '🔵';
      default:
        return '';
    }
  }

  /// true wenn urgency angezeigt werden soll.
  bool get hasUrgency => urgency != null && urgency!.isNotEmpty;
}
