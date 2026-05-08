import 'package:flutter/material.dart';

enum CrisisUrgency {
  critical,
  high,
  medium,
  low;

  static CrisisUrgency fromString(String? raw) {
    switch (raw) {
      case 'critical':
        return CrisisUrgency.critical;
      case 'high':
        return CrisisUrgency.high;
      case 'medium':
        return CrisisUrgency.medium;
      case 'low':
        return CrisisUrgency.low;
      default:
        return CrisisUrgency.medium;
    }
  }

  String get value {
    switch (this) {
      case CrisisUrgency.critical:
        return 'critical';
      case CrisisUrgency.high:
        return 'high';
      case CrisisUrgency.medium:
        return 'medium';
      case CrisisUrgency.low:
        return 'low';
    }
  }

  String get label {
    switch (this) {
      case CrisisUrgency.critical:
        return 'Kritisch';
      case CrisisUrgency.high:
        return 'Hoch';
      case CrisisUrgency.medium:
        return 'Mittel';
      case CrisisUrgency.low:
        return 'Niedrig';
    }
  }

  Color get color {
    switch (this) {
      case CrisisUrgency.critical:
        return const Color(0xFFB91C1C);
      case CrisisUrgency.high:
        return const Color(0xFFD97706);
      case CrisisUrgency.medium:
        return const Color(0xFF1D4ED8);
      case CrisisUrgency.low:
        return const Color(0xFF374151);
    }
  }
}

enum CrisisStatus {
  active,
  inProgress,
  resolved,
  falseAlarm,
  cancelled,
  unknown;

  static CrisisStatus fromString(String? raw) {
    switch (raw) {
      case 'active':
        return CrisisStatus.active;
      case 'in_progress':
        return CrisisStatus.inProgress;
      case 'resolved':
        return CrisisStatus.resolved;
      case 'false_alarm':
        return CrisisStatus.falseAlarm;
      case 'cancelled':
        return CrisisStatus.cancelled;
      default:
        return CrisisStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case CrisisStatus.active:
        return 'Aktiv';
      case CrisisStatus.inProgress:
        return 'Hilfe läuft';
      case CrisisStatus.resolved:
        return 'Geklärt';
      case CrisisStatus.falseAlarm:
        return 'Fehlalarm';
      case CrisisStatus.cancelled:
        return 'Abgebrochen';
      case CrisisStatus.unknown:
        return '–';
    }
  }

  Color get color {
    switch (this) {
      case CrisisStatus.active:
        return const Color(0xFFB91C1C);
      case CrisisStatus.inProgress:
        return const Color(0xFFD97706);
      case CrisisStatus.resolved:
        return const Color(0xFF15803D);
      case CrisisStatus.falseAlarm:
      case CrisisStatus.cancelled:
        return const Color(0xFF6B7280);
      case CrisisStatus.unknown:
        return const Color(0xFF6B7280);
    }
  }
}

class CrisisCategory {
  const CrisisCategory({required this.value, required this.label, required this.emoji});
  final String value;
  final String label;
  final String emoji;

  static const all = <CrisisCategory>[
    CrisisCategory(value: 'medical', label: 'Medizinisch', emoji: '🚑'),
    CrisisCategory(value: 'fire', label: 'Feuer', emoji: '🔥'),
    CrisisCategory(value: 'flood', label: 'Hochwasser', emoji: '💧'),
    CrisisCategory(value: 'storm', label: 'Sturm', emoji: '⛈️'),
    CrisisCategory(value: 'accident', label: 'Unfall', emoji: '🚗'),
    CrisisCategory(value: 'violence', label: 'Gewalt', emoji: '🛡️'),
    CrisisCategory(value: 'missing_person', label: 'Vermisst', emoji: '🔍'),
    CrisisCategory(value: 'infrastructure', label: 'Infrastruktur', emoji: '🔧'),
    CrisisCategory(value: 'supply', label: 'Versorgung', emoji: '📦'),
    CrisisCategory(value: 'evacuation', label: 'Evakuierung', emoji: '🚪'),
    CrisisCategory(value: 'other', label: 'Sonstiges', emoji: '❓'),
  ];

  static CrisisCategory forValue(String? value) {
    for (final c in all) {
      if (c.value == value) return c;
    }
    return const CrisisCategory(value: 'other', label: 'Sonstiges', emoji: '❓');
  }
}

class Crisis {
  const Crisis({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    required this.radiusKm,
    required this.affectedCount,
    required this.helperCount,
    required this.neededHelpers,
    required this.isAnonymous,
    required this.isVerified,
    required this.imageUrls,
    required this.neededSkills,
    required this.neededResources,
    required this.createdAt,
    this.locationText,
    this.latitude,
    this.longitude,
    this.contactPhone,
    this.contactName,
    this.distanceKm,
    this.creatorName,
    this.creatorAvatarUrl,
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String category;
  final CrisisUrgency urgency;
  final CrisisStatus status;
  final double radiusKm;
  final int affectedCount;
  final int helperCount;
  final int neededHelpers;
  final bool isAnonymous;
  final bool isVerified;
  final List<String> imageUrls;
  final List<String> neededSkills;
  final List<String> neededResources;
  final DateTime createdAt;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;
  final String? contactName;
  final double? distanceKm;
  final String? creatorName;
  final String? creatorAvatarUrl;

  CrisisCategory get categoryConfig => CrisisCategory.forValue(category);

  factory Crisis.fromJson(Map<String, dynamic> j) {
    List<String> stringList(Object? v) {
      if (v is List) return v.whereType<String>().toList();
      return const [];
    }

    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final profile = j['profiles'] as Map<String, dynamic>?;

    return Crisis(
      id: j['id'] as String,
      creatorId: j['creator_id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      category: j['category'] as String? ?? 'other',
      urgency: CrisisUrgency.fromString(j['urgency'] as String?),
      status: CrisisStatus.fromString(j['status'] as String?),
      radiusKm: parseDouble(j['radius_km']) ?? 5,
      affectedCount: (j['affected_count'] as num?)?.toInt() ?? 0,
      helperCount: (j['helper_count'] as num?)?.toInt() ?? 0,
      neededHelpers: (j['needed_helpers'] as num?)?.toInt() ?? 0,
      isAnonymous: j['is_anonymous'] as bool? ?? false,
      isVerified: j['is_verified'] as bool? ?? false,
      imageUrls: stringList(j['image_urls']),
      neededSkills: stringList(j['needed_skills']),
      neededResources: stringList(j['needed_resources']),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      locationText: j['location_text'] as String?,
      latitude: parseDouble(j['latitude']),
      longitude: parseDouble(j['longitude']),
      contactPhone: j['contact_phone'] as String?,
      contactName: j['contact_name'] as String?,
      distanceKm: parseDouble(j['distance_km']),
      creatorName: profile?['name'] as String?,
      creatorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

class CrisisHelper {
  const CrisisHelper({
    required this.id,
    required this.crisisId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.message,
    this.skills = const [],
    this.etaMinutes,
    this.profileName,
    this.profileAvatarUrl,
  });

  final String id;
  final String crisisId;
  final String userId;
  final String status;
  final DateTime createdAt;
  final String? message;
  final List<String> skills;
  final int? etaMinutes;
  final String? profileName;
  final String? profileAvatarUrl;

  factory CrisisHelper.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return CrisisHelper(
      id: j['id'] as String,
      crisisId: j['crisis_id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      status: j['status'] as String? ?? 'offered',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      message: j['message'] as String?,
      skills: (j['skills'] is List)
          ? (j['skills'] as List).whereType<String>().toList()
          : const [],
      etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
      profileName: profile?['name'] as String?,
      profileAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
