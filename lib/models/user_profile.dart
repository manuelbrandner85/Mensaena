class UserProfile {
  final String id;
  final String? name;
  final String? nickname;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final double? latitude;
  final double? longitude;
  final List<String> skills;
  final double trustScore;
  final double impactScore;
  final String? role;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Settings fields
  final bool? notifyMessages;
  final bool? notifyInteractions;
  final bool? notifyNearby;
  final bool? notifySystem;
  final bool? notifyPush;
  final bool? profilePublic;
  final bool? showLocation;
  final bool? showEmail;
  final bool? showPhone;
  final String? phone;

  const UserProfile({
    required this.id,
    this.name,
    this.nickname,
    this.email,
    this.bio,
    this.avatarUrl,
    this.location,
    this.latitude,
    this.longitude,
    this.skills = const [],
    this.trustScore = 0,
    this.impactScore = 0,
    this.role,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.notifyMessages,
    this.notifyInteractions,
    this.notifyNearby,
    this.notifySystem,
    this.notifyPush,
    this.profilePublic,
    this.showLocation,
    this.showEmail,
    this.showPhone,
    this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
      impactScore: (json['impact_score'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      notifyMessages: json['notify_messages'] as bool?,
      notifyInteractions: json['notify_interactions'] as bool?,
      notifyNearby: json['notify_nearby'] as bool?,
      notifySystem: json['notify_system'] as bool?,
      notifyPush: json['notify_push'] as bool?,
      profilePublic: json['profile_public'] as bool?,
      showLocation: json['show_location'] as bool?,
      showEmail: json['show_email'] as bool?,
      showPhone: json['show_phone'] as bool?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'email': email,
      'bio': bio,
      'avatar_url': avatarUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'skills': skills,
      'trust_score': trustScore,
      'impact_score': impactScore,
      'role': role,
      'is_verified': isVerified,
      'notify_messages': notifyMessages,
      'notify_interactions': notifyInteractions,
      'notify_nearby': notifyNearby,
      'notify_system': notifySystem,
      'notify_push': notifyPush,
      'profile_public': profilePublic,
      'show_location': showLocation,
      'show_email': showEmail,
      'show_phone': showPhone,
      'phone': phone,
    };
  }

  String get displayName => nickname ?? name ?? 'Anonym';

  String get initials {
    final n = displayName;
    if (n.isEmpty) return '?';
    final parts = n.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n[0].toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? bio,
    String? avatarUrl,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? skills,
    String? phone,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      skills: skills ?? this.skills,
      trustScore: trustScore,
      impactScore: impactScore,
      role: role,
      isVerified: isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
      phone: phone ?? this.phone,
    );
  }
}
