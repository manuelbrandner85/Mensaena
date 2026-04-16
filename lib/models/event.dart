class Event {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? category;
  final DateTime eventDate;
  final String? eventTime;
  final String? endTime;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final int? maxAttendees;
  final double? cost;
  final String? currency;
  final bool isOnline;
  final String? onlineUrl;
  final String? contactPhone;
  final String? contactEmail;
  final List<String> tags;
  final String status;
  final bool isRecurring;
  final String? recurringPattern;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? profile;
  final int? attendeeCount;
  final String? userAttendance;

  const Event({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    required this.eventDate,
    this.eventTime,
    this.endTime,
    this.locationText,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.maxAttendees,
    this.cost,
    this.currency,
    this.isOnline = false,
    this.onlineUrl,
    this.contactPhone,
    this.contactEmail,
    this.tags = const [],
    this.status = 'upcoming',
    this.isRecurring = false,
    this.recurringPattern,
    required this.createdAt,
    this.updatedAt,
    this.profile,
    this.attendeeCount,
    this.userAttendance,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      eventTime: json['event_time'] as String?,
      endTime: json['end_time'] as String?,
      locationText: json['location_text'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      maxAttendees: json['max_attendees'] as int?,
      cost: (json['cost'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      onlineUrl: json['online_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'upcoming',
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringPattern: json['recurring_pattern'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] as Map<String, dynamic>?,
      attendeeCount: json['attendee_count'] as int?,
      userAttendance: json['user_attendance'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'event_time': eventTime,
      'end_time': endTime,
      'location_text': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'max_attendees': maxAttendees,
      'cost': cost,
      'currency': currency,
      'is_online': isOnline,
      'online_url': onlineUrl,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'tags': tags,
      'status': status,
      'is_recurring': isRecurring,
      'recurring_pattern': recurringPattern,
    };
  }

  bool get isPast => eventDate.isBefore(DateTime.now());
  bool get isFull => maxAttendees != null && (attendeeCount ?? 0) >= maxAttendees!;
  bool get isFree => cost == null || cost == 0;
}
