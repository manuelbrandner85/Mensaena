import 'package:flutter/material.dart';

import '../messages/models.dart';

class PostTypeConfig {
  const PostTypeConfig({
    required this.label,
    required this.emoji,
    required this.color,
    required this.background,
  });

  final String label;
  final String emoji;
  final Color color;
  final Color background;

  static const Map<String, PostTypeConfig> _configs = {
    'rescue': PostTypeConfig(
      label: 'Hilfe / Retten',
      emoji: '🧡',
      color: Color(0xFFB45309),
      background: Color(0xFFFFF7ED),
    ),
    'animal': PostTypeConfig(
      label: 'Tierhilfe',
      emoji: '🐾',
      color: Color(0xFFBE185D),
      background: Color(0xFFFDF2F8),
    ),
    'housing': PostTypeConfig(
      label: 'Wohnangebot',
      emoji: '🏡',
      color: Color(0xFF1D4ED8),
      background: Color(0xFFEFF6FF),
    ),
    'supply': PostTypeConfig(
      label: 'Versorgung',
      emoji: '🌾',
      color: Color(0xFFA16207),
      background: Color(0xFFFEFCE8),
    ),
    'mobility': PostTypeConfig(
      label: 'Mobilität',
      emoji: '🚗',
      color: Color(0xFF4338CA),
      background: Color(0xFFEEF2FF),
    ),
    'sharing': PostTypeConfig(
      label: 'Teilen / Skill',
      emoji: '🔄',
      color: Color(0xFF0F766E),
      background: Color(0xFFF0FDFA),
    ),
    'community': PostTypeConfig(
      label: 'Community',
      emoji: '🗳️',
      color: Color(0xFF6D28D9),
      background: Color(0xFFF5F3FF),
    ),
    'crisis': PostTypeConfig(
      label: 'Notfall',
      emoji: '🚨',
      color: Color(0xFFB91C1C),
      background: Color(0xFFFEE2E2),
    ),
  };

  static const PostTypeConfig fallback = PostTypeConfig(
    label: 'Beitrag',
    emoji: '📝',
    color: Color(0xFF374151),
    background: Color(0xFFF9FAFB),
  );

  static PostTypeConfig forType(String type) => _configs[type] ?? fallback;

  static const List<({String value, String label})> filters = [
    (value: 'all', label: 'Alle'),
    (value: 'rescue', label: 'Retten'),
    (value: 'animal', label: 'Tier'),
    (value: 'housing', label: 'Wohnen'),
    (value: 'supply', label: 'Versorgung'),
    (value: 'crisis', label: 'Notfall'),
    (value: 'mobility', label: 'Mobilität'),
    (value: 'sharing', label: 'Teilen'),
    (value: 'community', label: 'Community'),
  ];
}

class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.createdAt,
    this.category,
    this.description,
    this.locationText,
    this.latitude,
    this.longitude,
    this.contactPhone,
    this.contactEmail,
    this.contactWhatsapp,
    this.urgency,
    this.isAnonymous = false,
    this.isRecurring = false,
    this.mediaUrls = const [],
    this.tags = const [],
    this.status = 'active',
    this.privacyPhone = false,
    this.privacyEmail = false,
    this.author,
    this.reactionCount = 0,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final DateTime createdAt;
  final String? category;
  final String? description;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactWhatsapp;
  final int? urgency;
  final bool isAnonymous;
  final bool isRecurring;
  final List<String> mediaUrls;
  final List<String> tags;
  final String status;
  final bool privacyPhone;
  final bool privacyEmail;
  final Profile? author;
  final int reactionCount;

  PostTypeConfig get typeConfig => PostTypeConfig.forType(type);

  factory Post.fromJson(Map<String, dynamic> j) {
    final profileData = j['profiles'] as Map<String, dynamic>?;
    Profile? author;
    if (profileData != null) {
      author = Profile.fromJson(profileData);
    }

    int? parseInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    List<String> parseStringList(Object? v) {
      if (v is List) {
        return v.whereType<String>().toList();
      }
      return const [];
    }

    return Post(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      type: j['type'] as String? ?? 'community',
      title: j['title'] as String? ?? '',
      createdAt: DateTime.parse(j['created_at'] as String),
      category: j['category'] as String?,
      description: j['description'] as String?,
      locationText: j['location_text'] as String?,
      latitude: parseDouble(j['latitude']),
      longitude: parseDouble(j['longitude']),
      contactPhone: j['contact_phone'] as String?,
      contactEmail: j['contact_email'] as String?,
      contactWhatsapp: j['contact_whatsapp'] as String?,
      urgency: parseInt(j['urgency']),
      isAnonymous: j['is_anonymous'] as bool? ?? false,
      isRecurring: j['is_recurring'] as bool? ?? false,
      mediaUrls: parseStringList(j['media_urls']),
      tags: parseStringList(j['tags']),
      status: j['status'] as String? ?? 'active',
      privacyPhone: j['privacy_phone'] as bool? ?? false,
      privacyEmail: j['privacy_email'] as bool? ?? false,
      author: author,
      reactionCount: parseInt(j['reaction_count']) ?? 0,
    );
  }
}
