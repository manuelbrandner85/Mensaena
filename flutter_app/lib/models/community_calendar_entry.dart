import 'package:flutter/material.dart';

import '../config/theme/app_colors.dart';

enum CommunityCalendarType { event, timebankSlot, groupMeeting, skillWindow }

/// Aggregierter Kalender-Eintrag aus mehreren Quell-Tabellen:
/// events, timebank_entries (offene Slots), groups (Treffen), skill_offers (Zeitfenster).
class CommunityCalendarEntry {
  const CommunityCalendarEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.startDate,
    this.endDate,
    this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    this.category,
    this.sourceId,
    this.routePath,
  });

  final String id;
  final CommunityCalendarType type;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? sourceId;
  final String? routePath;

  Color get color {
    switch (type) {
      case CommunityCalendarType.event:
        return _eventCategoryColor(category);
      case CommunityCalendarType.timebankSlot:
        return AppColors.leben;
      case CommunityCalendarType.groupMeeting:
        return AppColors.teal;
      case CommunityCalendarType.skillWindow:
        return AppColors.trust;
    }
  }

  static Color _eventCategoryColor(String? category) {
    switch (category) {
      case 'community':
        return AppColors.primary500;
      case 'helping':
        return AppColors.leben;
      case 'sharing':
        return AppColors.teal;
      case 'learning':
        return AppColors.tealSoft;
      case 'celebration':
        return AppColors.amberWarm;
      case 'sport':
        return AppColors.herzrotWarm;
      case 'crisis':
        return AppColors.herzrot;
      default:
        return AppColors.mute;
    }
  }
}

/// Parameter-Objekt für communityCalendarProvider.family.
class CalendarParams {
  const CalendarParams({
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  final double lat;
  final double lng;
  final double radiusKm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarParams &&
          other.lat == lat &&
          other.lng == lng &&
          other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm);
}
