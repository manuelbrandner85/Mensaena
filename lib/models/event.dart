/// Kategorie-Konfiguration fuer Events.
class EventCategoryConfig {
  final String value;
  final String label;
  final String emoji;

  const EventCategoryConfig(this.value, this.label, this.emoji);

  static const Map<String, EventCategoryConfig> categories = {
    'meetup': EventCategoryConfig('meetup', 'Treffen', '👥'),
    'workshop': EventCategoryConfig('workshop', 'Workshop', '🎓'),
    'sport': EventCategoryConfig('sport', 'Sport', '🏃'),
    'food': EventCategoryConfig('food', 'Essen & Trinken', '🍽️'),
    'market': EventCategoryConfig('market', 'Flohmarkt', '🛍️'),
    'culture': EventCategoryConfig('culture', 'Kultur', '🎵'),
    'kids': EventCategoryConfig('kids', 'Kinder', '👶'),
    'seniors': EventCategoryConfig('seniors', 'Senioren', '❤️'),
    'cleanup': EventCategoryConfig('cleanup', 'Aufraeumaktion', '♻️'),
    'other': EventCategoryConfig('other', 'Sonstiges', '📌'),
  };

  static EventCategoryConfig fromString(String? value) {
    return categories[value] ?? categories['other']!;
  }
}

class Event {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? category;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isAllDay;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final int? maxAttendees;
  final String? cost;
  final String? whatToBring;
  final String? contactInfo;
  final bool isRecurring;
  final String status;
  final int attendeeCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? profile;
  final String? myAttendance;

  const Event({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    required this.startDate,
    this.endDate,
    this.isAllDay = false,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.maxAttendees,
    this.cost,
    this.whatToBring,
    this.contactInfo,
    this.isRecurring = false,
    this.status = 'upcoming',
    this.attendeeCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.profile,
    this.myAttendance,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      userId: json['author_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      isAllDay: json['is_all_day'] as bool? ?? false,
      locationName: json['location_name'] as String?,
      locationAddress: json['location_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      maxAttendees: json['max_attendees'] as int?,
      cost: json['cost']?.toString(),
      whatToBring: json['what_to_bring'] as String?,
      contactInfo: json['contact_info'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      status: json['status'] as String? ?? 'upcoming',
      attendeeCount: json['attendee_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] as Map<String, dynamic>?,
      myAttendance: json['my_attendance'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_all_day': isAllDay,
      'location_name': locationName,
      'location_address': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'max_attendees': maxAttendees,
      'cost': cost,
      'what_to_bring': whatToBring,
      'contact_info': contactInfo,
      'is_recurring': isRecurring,
      'status': status,
    };
  }

  Event copyWith({
    String? myAttendance,
    int? attendeeCount,
  }) {
    return Event(
      id: id,
      userId: userId,
      title: title,
      description: description,
      category: category,
      startDate: startDate,
      endDate: endDate,
      isAllDay: isAllDay,
      locationName: locationName,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      maxAttendees: maxAttendees,
      cost: cost,
      whatToBring: whatToBring,
      contactInfo: contactInfo,
      isRecurring: isRecurring,
      status: status,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      profile: profile,
      myAttendance: myAttendance ?? this.myAttendance,
    );
  }

  bool get isPast => startDate.isBefore(DateTime.now());
  bool get isFull =>
      maxAttendees != null && attendeeCount >= maxAttendees!;
  bool get isFree =>
      cost == null || cost == 'kostenlos' || cost == '0' || cost!.isEmpty;

  String get locationDisplay {
    if (locationName != null && locationAddress != null) {
      return '$locationName, $locationAddress';
    }
    return locationName ?? locationAddress ?? '';
  }

  EventCategoryConfig get categoryConfig =>
      EventCategoryConfig.fromString(category);
}
