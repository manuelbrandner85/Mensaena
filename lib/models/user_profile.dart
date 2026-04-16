class UserProfile {
  final String id;
  final String? name;
  final String? nickname;
  final String? displayNameField;
  final String? username;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final String? address;
  final String? homeCity;
  final String? homePostalCode;
  final String? country;
  final String? region;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final List<String> skills;
  final double trustScore;
  final double impactScore;
  final int? karmaPoints;
  final int? points;
  final String? level;
  final String? role;
  final bool isVerified;
  final bool? isBanned;
  final bool? isCrisisVolunteer;
  final List<String> crisisSkills;
  final List<String> offerTags;
  final List<String> seekTags;
  final bool? onboardingCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

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
  final bool? showOnlineStatus;
  final bool? showTrustScore;
  final bool? showActivity;
  final bool? allowMatching;
  final String? allowMessagesFrom;
  final String? phone;
  final String? homepage;

  const UserProfile({
    required this.id,
    this.name,
    this.nickname,
    this.displayNameField,
    this.username,
    this.email,
    this.bio,
    this.avatarUrl,
    this.location,
    this.address,
    this.homeCity,
    this.homePostalCode,
    this.country,
    this.region,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.skills = const [],
    this.trustScore = 0,
    this.impactScore = 0,
    this.karmaPoints,
    this.points,
    this.level,
    this.role,
    this.isVerified = false,
    this.isBanned,
    this.isCrisisVolunteer,
    this.crisisSkills = const [],
    this.offerTags = const [],
    this.seekTags = const [],
    this.onboardingCompleted,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.notifyMessages,
    this.notifyInteractions,
    this.notifyNearby,
    this.notifySystem,
    this.notifyPush,
    this.profilePublic,
    this.showLocation,
    this.showEmail,
    this.showPhone,
    this.showOnlineStatus,
    this.showTrustScore,
    this.showActivity,
    this.allowMatching,
    this.allowMessagesFrom,
    this.phone,
    this.homepage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      nickname: json['nickname'] as String?,
      displayNameField: json['display_name'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      location: json['location'] as String?,
      address: json['address'] as String?,
      homeCity: json['home_city'] as String?,
      homePostalCode: json['home_postal_code'] as String?,
      country: json['country'] as String?,
      region: json['region'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['home_lat'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['home_lng'] as num?)?.toDouble(),
      radiusKm: json['radius_km'] as int?,
      skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
      impactScore: (json['impact_score'] as num?)?.toDouble() ?? 0,
      karmaPoints: json['karma_points'] as int?,
      points: json['points'] as int?,
      level: json['level'] as String?,
      role: json['role'] as String?,
      isVerified: json['verified_email'] as bool? ?? json['verified_community'] as bool? ?? false,
      isBanned: json['is_banned'] as bool?,
      isCrisisVolunteer: json['is_crisis_volunteer'] as bool?,
      crisisSkills: (json['crisis_skills'] as List<dynamic>?)?.cast<String>() ?? [],
      offerTags: (json['offer_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      seekTags: (json['seek_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      onboardingCompleted: json['onboarding_completed'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      lastLoginAt: json['last_login_at'] != null ? DateTime.parse(json['last_login_at'] as String) : null,
      notifyMessages: json['notify_messages'] as bool? ?? json['notify_new_messages'] as bool?,
      notifyInteractions: json['notify_interactions'] as bool? ?? json['notify_new_interactions'] as bool?,
      notifyNearby: json['notify_nearby'] as bool? ?? json['notify_nearby_posts'] as bool?,
      notifySystem: json['notify_system'] as bool?,
      notifyPush: json['notify_push'] as bool?,
      profilePublic: json['profile_public'] as bool? ?? json['privacy_public'] as bool?,
      showLocation: json['show_location'] as bool? ?? json['privacy_location'] as bool?,
      showEmail: json['show_email'] as bool? ?? json['privacy_email'] as bool?,
      showPhone: json['show_phone'] as bool? ?? json['privacy_phone'] as bool?,
      showOnlineStatus: json['show_online_status'] as bool?,
      showTrustScore: json['show_trust_score'] as bool?,
      showActivity: json['show_activity'] as bool?,
      allowMatching: json['allow_matching'] as bool?,
      allowMessagesFrom: json['allow_messages_from'] as String?,
      phone: json['phone'] as String?,
      homepage: json['homepage'] as String?,
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
      'homepage': homepage,
    };
  }

  String get displayName => displayNameField ?? nickname ?? name ?? 'Anonym';

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
    String? homepage,
    bool? profilePublic,
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
      homepage: homepage ?? this.homepage,
      profilePublic: profilePublic ?? this.profilePublic,
    );
  }
}
