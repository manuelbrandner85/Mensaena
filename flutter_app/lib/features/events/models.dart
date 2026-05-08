import 'package:flutter/material.dart';

class EventCategory {
  const EventCategory({required this.value, required this.label, required this.emoji, required this.color});
  final String value;
  final String label;
  final String emoji;
  final Color color;

  static const all = <EventCategory>[
    EventCategory(value: 'meetup', label: 'Treffen', emoji: '👥', color: Color(0xFF8B5CF6)),
    EventCategory(value: 'workshop', label: 'Workshop', emoji: '🎓', color: Color(0xFF3B82F6)),
    EventCategory(value: 'sport', label: 'Sport', emoji: '🏃', color: Color(0xFF10B981)),
    EventCategory(value: 'food', label: 'Essen', emoji: '🍽️', color: Color(0xFFF97316)),
    EventCategory(value: 'market', label: 'Flohmarkt', emoji: '🛍️', color: Color(0xFFD97706)),
    EventCategory(value: 'culture', label: 'Kultur', emoji: '🎵', color: Color(0xFFEC4899)),
    EventCategory(value: 'kids', label: 'Kinder', emoji: '👶', color: Color(0xFF06B6D4)),
    EventCategory(value: 'other', label: 'Sonstiges', emoji: '📅', color: Color(0xFF64748B)),
  ];

  static EventCategory forValue(String? v) {
    for (final c in all) {
      if (c.value == v) return c;
    }
    return all.last;
  }
}

enum AttendeeStatus {
  going,
  maybe,
  notGoing;

  String get value {
    switch (this) {
      case AttendeeStatus.going:
        return 'going';
      case AttendeeStatus.maybe:
        return 'maybe';
      case AttendeeStatus.notGoing:
        return 'not_going';
    }
  }

  static AttendeeStatus? fromString(String? raw) {
    switch (raw) {
      case 'going':
        return AttendeeStatus.going;
      case 'maybe':
        return AttendeeStatus.maybe;
      case 'not_going':
        return AttendeeStatus.notGoing;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case AttendeeStatus.going:
        return 'Bin dabei';
      case AttendeeStatus.maybe:
        return 'Vielleicht';
      case AttendeeStatus.notGoing:
        return 'Nein';
    }
  }
}

class EventItem {
  const EventItem({
    required this.id,
    required this.authorId,
    required this.title,
    required this.category,
    required this.startDate,
    required this.isAllDay,
    required this.isOnline,
    required this.attendeeCount,
    required this.status,
    required this.createdAt,
    this.description,
    this.endDate,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.maxAttendees,
    this.cost,
    this.onlineUrl,
    this.myAttendance,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final String title;
  final String category;
  final DateTime startDate;
  final bool isAllDay;
  final bool isOnline;
  final int attendeeCount;
  final String status;
  final DateTime createdAt;
  final String? description;
  final DateTime? endDate;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final int? maxAttendees;
  final String? cost;
  final String? onlineUrl;
  final AttendeeStatus? myAttendance;
  final String? authorName;
  final String? authorAvatarUrl;

  EventCategory get categoryConfig => EventCategory.forValue(category);

  factory EventItem.fromJson(Map<String, dynamic> j) {
    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final profile = j['profiles'] as Map<String, dynamic>?;
    return EventItem(
      id: j['id'] as String,
      authorId: j['author_id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      category: j['category'] as String? ?? 'other',
      startDate: DateTime.tryParse(j['start_date'] as String? ?? '') ??
          DateTime.now(),
      isAllDay: j['is_all_day'] as bool? ?? false,
      isOnline: j['is_online'] as bool? ?? false,
      attendeeCount: (j['attendee_count'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      description: j['description'] as String?,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      locationName: j['location_name'] as String?,
      locationAddress: j['location_address'] as String?,
      latitude: parseDouble(j['latitude']),
      longitude: parseDouble(j['longitude']),
      imageUrl: j['image_url'] as String?,
      maxAttendees: (j['max_attendees'] as num?)?.toInt(),
      cost: j['cost'] as String?,
      onlineUrl: j['online_url'] as String?,
      myAttendance: AttendeeStatus.fromString(j['my_attendance'] as String?),
      authorName: profile?['name'] as String? ?? profile?['display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
