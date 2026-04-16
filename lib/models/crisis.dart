enum CrisisCategory {
  medical('medical', 'Medizinisch', '🏥'),
  fire('fire', 'Feuer', '🔥'),
  flood('flood', 'Hochwasser', '🌊'),
  storm('storm', 'Unwetter', '🌪️'),
  accident('accident', 'Unfall', '🚨'),
  violence('violence', 'Gewalt', '🛡️'),
  missingPerson('missing_person', 'Vermisst', '🔍'),
  infrastructure('infrastructure', 'Infrastruktur', '🔧'),
  supply('supply', 'Versorgung', '📦'),
  evacuation('evacuation', 'Evakuierung', '🚁'),
  other('other', 'Sonstiges', '⚠️');

  const CrisisCategory(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static CrisisCategory fromString(String value) {
    return CrisisCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CrisisCategory.other,
    );
  }
}

enum CrisisUrgency {
  critical('critical', 'Kritisch'),
  high('high', 'Hoch'),
  medium('medium', 'Mittel'),
  low('low', 'Niedrig');

  const CrisisUrgency(this.value, this.label);
  final String value;
  final String label;

  static CrisisUrgency fromString(String value) {
    return CrisisUrgency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CrisisUrgency.medium,
    );
  }
}

enum CrisisStatus {
  active('active', 'Aktiv'),
  inProgress('in_progress', 'In Bearbeitung'),
  resolved('resolved', 'Gelöst'),
  falseAlarm('false_alarm', 'Fehlalarm'),
  cancelled('cancelled', 'Abgebrochen');

  const CrisisStatus(this.value, this.label);
  final String value;
  final String label;

  static CrisisStatus fromString(String value) {
    return CrisisStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CrisisStatus.active,
    );
  }
}

class Crisis {
  final String id;
  final String reporterId;
  final String title;
  final String? description;
  final String type;
  final String? severity;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? country;
  final String status;
  final String? contactPhone;
  final bool isAnonymous;
  final bool verified;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  // Joined
  final Map<String, dynamic>? reporterProfile;
  final int? helperCount;
  final int? updateCount;

  const Crisis({
    required this.id,
    required this.reporterId,
    required this.title,
    this.description,
    required this.type,
    this.severity,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.country,
    this.status = 'active',
    this.contactPhone,
    this.isAnonymous = false,
    this.verified = false,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.reporterProfile,
    this.helperCount,
    this.updateCount,
  });

  factory Crisis.fromJson(Map<String, dynamic> json) {
    return Crisis(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'other',
      severity: json['severity'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      status: json['status'] as String? ?? 'active',
      contactPhone: json['contact_phone'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      reporterProfile: json['profiles'] as Map<String, dynamic>?,
      helperCount: json['helper_count'] as int?,
      updateCount: json['update_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporter_id': reporterId,
      'title': title,
      'description': description,
      'type': type,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'status': status,
      'contact_phone': contactPhone,
      'is_anonymous': isAnonymous,
    };
  }

  CrisisCategory get crisisCategory => CrisisCategory.fromString(type);
  CrisisStatus get crisisStatus => CrisisStatus.fromString(status);
  CrisisUrgency get urgency =>
      CrisisUrgency.fromString(severity ?? 'medium');
}

class CrisisHelper {
  final String id;
  final String crisisId;
  final String userId;
  final String status;
  final String? message;
  final List<String> skills;
  final List<String> resources;
  final DateTime createdAt;
  final Map<String, dynamic>? profile;

  const CrisisHelper({
    required this.id,
    required this.crisisId,
    required this.userId,
    this.status = 'offered',
    this.message,
    this.skills = const [],
    this.resources = const [],
    required this.createdAt,
    this.profile,
  });

  factory CrisisHelper.fromJson(Map<String, dynamic> json) {
    return CrisisHelper(
      id: json['id'] as String,
      crisisId: json['crisis_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'offered',
      message: json['message'] as String?,
      skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      resources: (json['resources'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}

class CrisisUpdate {
  final String id;
  final String crisisId;
  final String userId;
  final String type;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? profile;

  const CrisisUpdate({
    required this.id,
    required this.crisisId,
    required this.userId,
    required this.type,
    required this.content,
    required this.createdAt,
    this.profile,
  });

  factory CrisisUpdate.fromJson(Map<String, dynamic> json) {
    return CrisisUpdate(
      id: json['id'] as String,
      crisisId: json['crisis_id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'update',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
