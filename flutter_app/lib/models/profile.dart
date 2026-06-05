/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `profiles` (gyqujitkvymlmgroovch).
class Profile {
  const Profile({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    required this.donorTier,
    required this.donationCount,
    required this.donationTotal,
    this.name,
    this.nickname,
    this.email,
    this.location,
    this.skills = const [],
    this.avatarUrl,
    this.bio,
    this.trustScore = 0,
    this.impactScore = 0,
    this.notifyEmail = true,
    this.notifyMessages = true,
    this.notifyInteractions = true,
    this.notifyCommunity = true,
    this.notifyCrisis = true,
    this.privacyLocation = false,
    this.privacyEmail = false,
    this.privacyPhone = false,
    this.privacyPublic = true,
    this.homePostalCode,
    this.homeCity,
    this.homeLat,
    this.homeLng,
    this.country,
    this.region,
    this.preferredModules = const [],
    this.karmaPoints = 0,
    this.level,
    this.points = 0,
    this.verifiedEmail = false,
    this.verifiedPhone = false,
    this.verifiedCommunity = false,
    this.isVerified,
    this.verifiedAt,
    this.emergencyContact1Name,
    this.emergencyContact1Phone,
    this.emergencyContact2Name,
    this.emergencyContact2Phone,
    this.onboardingCompleted = false,
    this.lastLoginAt,
    this.inactiveReminderCount = 0,
    this.trustScoreCount = 0,
    this.trustLevel = 0,
    this.trustUpdatedAt,
    this.crisisBannedUntil,
    this.isCrisisVolunteer = false,
    this.crisisSkills = const [],
    this.isBanned = false,
    this.bannedAt,
    this.bannedBy,
    this.banReason,
    this.displayName,
    this.phone,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.username,
    this.homepage,
    this.address,
    this.notifyNewMessages = true,
    this.notifyNewInteractions = true,
    this.notifyNearbyPosts = true,
    this.notifyTrustRatings = true,
    this.notifySystem = true,
    this.notifyPush = true,
    this.notificationRadiusKm,
    this.notifyInactivityReminder = true,
    this.showOnlineStatus = true,
    this.showLocation = true,
    this.showTrustScore = true,
    this.showActivity = true,
    this.showPhone = false,
    this.allowMessagesFrom,
    this.readReceipts = true,
    this.allowMatching = true,
    this.profileVisibility,
    this.isMentor = false,
    this.mentorTopics = const [],
    this.emergencyContacts = const {},
    this.deletionRequestedAt,
    this.deletionConfirmed = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.offerTags = const [],
    this.seekTags = const [],
    this.coverUrl,
    this.statusText,
    this.statusEmoji,
    this.statusUntil,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String role;
  final int donorTier;
  final int donationCount;
  final double donationTotal;
  final String? name;
  final String? nickname;
  final String? email;
  final String? location;
  final List<String> skills;
  final String? avatarUrl;
  final String? bio;
  final int trustScore;
  final int impactScore;
  final bool notifyEmail;
  final bool notifyMessages;
  final bool notifyInteractions;
  final bool notifyCommunity;
  final bool notifyCrisis;
  final bool privacyLocation;
  final bool privacyEmail;
  final bool privacyPhone;
  final bool privacyPublic;
  final String? homePostalCode;
  final String? homeCity;
  final double? homeLat;
  final double? homeLng;
  final String? country;
  final String? region;
  final List<String> preferredModules;
  final int karmaPoints;
  final String? level;
  final int points;
  final bool verifiedEmail;
  final bool verifiedPhone;
  final bool verifiedCommunity;

  /// F35: globales Admin-verifiziertes Konto (blauer Haken).
  final bool? isVerified;
  final DateTime? verifiedAt;
  final String? emergencyContact1Name;
  final String? emergencyContact1Phone;
  final String? emergencyContact2Name;
  final String? emergencyContact2Phone;
  final bool onboardingCompleted;
  final DateTime? lastLoginAt;
  final int inactiveReminderCount;
  final int trustScoreCount;
  final int trustLevel;
  final DateTime? trustUpdatedAt;
  final DateTime? crisisBannedUntil;
  final bool isCrisisVolunteer;
  final List<String> crisisSkills;
  final bool isBanned;
  final DateTime? bannedAt;
  final String? bannedBy;
  final String? banReason;
  final String? displayName;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final String? username;
  final String? homepage;
  final String? address;
  final bool notifyNewMessages;
  final bool notifyNewInteractions;
  final bool notifyNearbyPosts;
  final bool notifyTrustRatings;
  final bool notifySystem;
  final bool notifyPush;
  final int? notificationRadiusKm;
  final bool notifyInactivityReminder;
  final bool showOnlineStatus;
  final bool showLocation;
  final bool showTrustScore;
  final bool showActivity;
  final bool showPhone;
  final String? allowMessagesFrom;
  final bool readReceipts;
  final bool allowMatching;
  final String? profileVisibility;
  final bool isMentor;
  final List<String> mentorTopics;
  final Map<String, dynamic> emergencyContacts;
  final DateTime? deletionRequestedAt;
  final bool deletionConfirmed;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final List<String> offerTags;
  final List<String> seekTags;
  final String? coverUrl;
  final String? statusText;
  final String? statusEmoji;
  final DateTime? statusUntil;

  bool get hasActiveStatus {
    if (statusText == null || statusText!.isEmpty) return false;
    if (statusUntil == null) return true;
    return statusUntil!.isAfter(DateTime.now());
  }

  factory Profile.fromJson(Map<String, dynamic> j) {
    // Postgres NUMERIC kommt via PostgREST manchmal als String (z.B.
    // "50.00") statt num — `as num?` waere TypeError. Helper parsed
    // beides defensiv. Selbe Logik fuer int.
    double nd(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    int ni(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    double? dn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    int? inn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }
    return Profile(
      id: j['id'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime(2000),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime(2000),
      role: (j['role'] as String?) ?? 'user',
      donorTier: ni(j['donor_tier']),
      donationCount: ni(j['donation_count']),
      donationTotal: nd(j['donation_total']),
      name: j['name'] as String?,
      nickname: j['nickname'] as String?,
      email: j['email'] as String?,
      location: j['location'] as String?,
      skills: (j['skills'] is List)
          ? (j['skills'] as List).whereType<String>().toList()
          : const [],
      avatarUrl: j['avatar_url'] as String?,
      bio: j['bio'] as String?,
      trustScore: ni(j['trust_score']),
      impactScore: ni(j['impact_score']),
      notifyEmail: (j['notify_email'] as bool?) ?? true,
      notifyMessages: (j['notify_messages'] as bool?) ?? true,
      notifyInteractions: (j['notify_interactions'] as bool?) ?? true,
      notifyCommunity: (j['notify_community'] as bool?) ?? true,
      notifyCrisis: (j['notify_crisis'] as bool?) ?? true,
      privacyLocation: (j['privacy_location'] as bool?) ?? false,
      privacyEmail: (j['privacy_email'] as bool?) ?? false,
      privacyPhone: (j['privacy_phone'] as bool?) ?? false,
      privacyPublic: (j['privacy_public'] as bool?) ?? true,
      homePostalCode: j['home_postal_code'] as String?,
      homeCity: j['home_city'] as String?,
      homeLat: dn(j['home_lat']),
      homeLng: dn(j['home_lng']),
      country: j['country'] as String?,
      region: j['region'] as String?,
      preferredModules: (j['preferred_modules'] is List)
          ? (j['preferred_modules'] as List).whereType<String>().toList()
          : const [],
      karmaPoints: ni(j['karma_points']),
      level: j['level'] as String?,
      points: ni(j['points']),
      verifiedEmail: (j['verified_email'] as bool?) ?? false,
      verifiedPhone: (j['verified_phone'] as bool?) ?? false,
      verifiedCommunity: (j['verified_community'] as bool?) ?? false,
      isVerified: j['is_verified'] as bool?,
      verifiedAt: j['verified_at'] != null
          ? DateTime.tryParse(j['verified_at'] as String)
          : null,
      emergencyContact1Name: j['emergency_contact_1_name'] as String?,
      emergencyContact1Phone: j['emergency_contact_1_phone'] as String?,
      emergencyContact2Name: j['emergency_contact_2_name'] as String?,
      emergencyContact2Phone: j['emergency_contact_2_phone'] as String?,
      onboardingCompleted: (j['onboarding_completed'] as bool?) ?? false,
      lastLoginAt: j['last_login_at'] != null
          ? DateTime.tryParse(j['last_login_at'] as String)
          : null,
      inactiveReminderCount:
          ni(j['inactive_reminder_count']),
      trustScoreCount: ni(j['trust_score_count']),
      trustLevel: ni(j['trust_level']),
      trustUpdatedAt: j['trust_updated_at'] != null
          ? DateTime.tryParse(j['trust_updated_at'] as String)
          : null,
      crisisBannedUntil: j['crisis_banned_until'] != null
          ? DateTime.tryParse(j['crisis_banned_until'] as String)
          : null,
      isCrisisVolunteer: (j['is_crisis_volunteer'] as bool?) ?? false,
      crisisSkills: (j['crisis_skills'] is List)
          ? (j['crisis_skills'] as List).whereType<String>().toList()
          : const [],
      isBanned: (j['is_banned'] as bool?) ?? false,
      bannedAt: j['banned_at'] != null
          ? DateTime.tryParse(j['banned_at'] as String)
          : null,
      bannedBy: j['banned_by'] as String?,
      banReason: j['ban_reason'] as String?,
      displayName: j['display_name'] as String?,
      phone: j['phone'] as String?,
      latitude: dn(j['latitude']),
      longitude: dn(j['longitude']),
      radiusKm: inn(j['radius_km']),
      username: j['username'] as String?,
      homepage: j['homepage'] as String?,
      address: j['address'] as String?,
      notifyNewMessages: (j['notify_new_messages'] as bool?) ?? true,
      notifyNewInteractions: (j['notify_new_interactions'] as bool?) ?? true,
      notifyNearbyPosts: (j['notify_nearby_posts'] as bool?) ?? true,
      notifyTrustRatings: (j['notify_trust_ratings'] as bool?) ?? true,
      notifySystem: (j['notify_system'] as bool?) ?? true,
      notifyPush: (j['notify_push'] as bool?) ?? true,
      notificationRadiusKm: inn(j['notification_radius_km']),
      notifyInactivityReminder:
          (j['notify_inactivity_reminder'] as bool?) ?? true,
      showOnlineStatus: (j['show_online_status'] as bool?) ?? true,
      showLocation: (j['show_location'] as bool?) ?? true,
      showTrustScore: (j['show_trust_score'] as bool?) ?? true,
      showActivity: (j['show_activity'] as bool?) ?? true,
      showPhone: (j['show_phone'] as bool?) ?? false,
      allowMessagesFrom: j['allow_messages_from'] as String?,
      readReceipts: (j['read_receipts'] as bool?) ?? true,
      allowMatching: (j['allow_matching'] as bool?) ?? true,
      profileVisibility: j['profile_visibility'] as String?,
      isMentor: (j['is_mentor'] as bool?) ?? false,
      mentorTopics: (j['mentor_topics'] is List)
          ? (j['mentor_topics'] as List).whereType<String>().toList()
          : const [],
      emergencyContacts: (j['emergency_contacts'] is Map)
          ? Map<String, dynamic>.from(j['emergency_contacts'] as Map)
          : const {},
      deletionRequestedAt: j['deletion_requested_at'] != null
          ? DateTime.tryParse(j['deletion_requested_at'] as String)
          : null,
      deletionConfirmed: (j['deletion_confirmed'] as bool?) ?? false,
      quietHoursEnabled: (j['quiet_hours_enabled'] as bool?) ?? false,
      quietHoursStart: j['quiet_hours_start'] as String?,
      quietHoursEnd: j['quiet_hours_end'] as String?,
      offerTags: (j['offer_tags'] is List)
          ? (j['offer_tags'] as List).whereType<String>().toList()
          : const [],
      seekTags: (j['seek_tags'] is List)
          ? (j['seek_tags'] as List).whereType<String>().toList()
          : const [],
      coverUrl: j['cover_url'] as String?,
      statusText: j['status_text'] as String?,
      statusEmoji: j['status_emoji'] as String?,
      statusUntil: j['status_until'] != null
          ? DateTime.tryParse(j['status_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'role': role,
        'donor_tier': donorTier,
        'donation_count': donationCount,
        'donation_total': donationTotal,
        'name': name,
        'nickname': nickname,
        'email': email,
        'location': location,
        'skills': skills,
        'avatar_url': avatarUrl,
        'bio': bio,
        'trust_score': trustScore,
        'impact_score': impactScore,
        'notify_email': notifyEmail,
        'notify_messages': notifyMessages,
        'notify_interactions': notifyInteractions,
        'notify_community': notifyCommunity,
        'notify_crisis': notifyCrisis,
        'privacy_location': privacyLocation,
        'privacy_email': privacyEmail,
        'privacy_phone': privacyPhone,
        'privacy_public': privacyPublic,
        'home_postal_code': homePostalCode,
        'home_city': homeCity,
        'home_lat': homeLat,
        'home_lng': homeLng,
        'country': country,
        'region': region,
        'preferred_modules': preferredModules,
        'karma_points': karmaPoints,
        'level': level,
        'points': points,
        'verified_email': verifiedEmail,
        'verified_phone': verifiedPhone,
        'verified_community': verifiedCommunity,
        'emergency_contact_1_name': emergencyContact1Name,
        'emergency_contact_1_phone': emergencyContact1Phone,
        'emergency_contact_2_name': emergencyContact2Name,
        'emergency_contact_2_phone': emergencyContact2Phone,
        'onboarding_completed': onboardingCompleted,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'inactive_reminder_count': inactiveReminderCount,
        'trust_score_count': trustScoreCount,
        'trust_level': trustLevel,
        'trust_updated_at': trustUpdatedAt?.toIso8601String(),
        'crisis_banned_until': crisisBannedUntil?.toIso8601String(),
        'is_crisis_volunteer': isCrisisVolunteer,
        'crisis_skills': crisisSkills,
        'is_banned': isBanned,
        'banned_at': bannedAt?.toIso8601String(),
        'banned_by': bannedBy,
        'ban_reason': banReason,
        'display_name': displayName,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'username': username,
        'homepage': homepage,
        'address': address,
        'notify_new_messages': notifyNewMessages,
        'notify_new_interactions': notifyNewInteractions,
        'notify_nearby_posts': notifyNearbyPosts,
        'notify_trust_ratings': notifyTrustRatings,
        'notify_system': notifySystem,
        'notify_push': notifyPush,
        'notification_radius_km': notificationRadiusKm,
        'notify_inactivity_reminder': notifyInactivityReminder,
        'show_online_status': showOnlineStatus,
        'show_location': showLocation,
        'show_trust_score': showTrustScore,
        'show_activity': showActivity,
        'show_phone': showPhone,
        'allow_messages_from': allowMessagesFrom,
        'read_receipts': readReceipts,
        'allow_matching': allowMatching,
        'profile_visibility': profileVisibility,
        'is_mentor': isMentor,
        'mentor_topics': mentorTopics,
        'emergency_contacts': emergencyContacts,
        'deletion_requested_at': deletionRequestedAt?.toIso8601String(),
        'deletion_confirmed': deletionConfirmed,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'offer_tags': offerTags,
        'seek_tags': seekTags,
        'cover_url': coverUrl,
        'status_text': statusText,
        'status_emoji': statusEmoji,
        'status_until': statusUntil?.toIso8601String(),
      };
}
