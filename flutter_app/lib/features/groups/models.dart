import 'package:flutter/material.dart';

class GroupCategory {
  const GroupCategory({
    required this.value,
    required this.label,
    required this.emoji,
    required this.accent,
  });
  final String value;
  final String label;
  final String emoji;
  final Color accent;

  static const all = <GroupCategory>[
    GroupCategory(value: 'nachbarschaft', label: 'Nachbarschaft', emoji: '🏘️', accent: Color(0xFF3B82F6)),
    GroupCategory(value: 'hobby', label: 'Hobby & Freizeit', emoji: '🎨', accent: Color(0xFFEC4899)),
    GroupCategory(value: 'sport', label: 'Sport & Fitness', emoji: '⚽', accent: Color(0xFFF97316)),
    GroupCategory(value: 'eltern', label: 'Eltern & Familie', emoji: '👶', accent: Color(0xFFF59E0B)),
    GroupCategory(value: 'senioren', label: 'Senioren', emoji: '🧓', accent: Color(0xFF8B5CF6)),
    GroupCategory(value: 'umwelt', label: 'Umwelt', emoji: '🌿', accent: Color(0xFF10B981)),
    GroupCategory(value: 'bildung', label: 'Bildung & Lernen', emoji: '📚', accent: Color(0xFF6366F1)),
    GroupCategory(value: 'tiere', label: 'Tiere', emoji: '🐾', accent: Color(0xFFD97706)),
    GroupCategory(value: 'handwerk', label: 'Handwerk & DIY', emoji: '🔧', accent: Color(0xFF64748B)),
    GroupCategory(value: 'sonstiges', label: 'Sonstiges', emoji: '💬', accent: Color(0xFF1EAAA6)),
  ];

  static GroupCategory forValue(String? v) {
    for (final c in all) {
      if (c.value == v) return c;
    }
    return all.last;
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.memberCount,
    required this.createdAt,
    this.description,
    this.imageUrl,
    this.coverImageUrl,
    this.avatarUrl,
    this.bannerUrl,
    this.isPrivate = false,
    this.postCount = 0,
    this.creatorId,
  });

  final String id;
  final String name;
  final String slug;
  final String category;
  final int memberCount;
  final DateTime createdAt;
  final String? description;
  final String? imageUrl;
  final String? coverImageUrl;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isPrivate;
  final int postCount;
  final String? creatorId;

  GroupCategory get categoryConfig => GroupCategory.forValue(category);
  String? get displayImage =>
      avatarUrl ?? imageUrl ?? coverImageUrl ?? bannerUrl;

  factory Group.fromJson(Map<String, dynamic> j) {
    int parseInt(Object? v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    return Group(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      category: j['category'] as String? ?? 'sonstiges',
      memberCount: parseInt(j['member_count']),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      description: j['description'] as String?,
      imageUrl: j['image_url'] as String?,
      coverImageUrl: j['cover_image_url'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      bannerUrl: j['banner_url'] as String?,
      isPrivate: (j['is_private'] as bool?) ?? false,
      postCount: parseInt(j['post_count']),
      creatorId: (j['creator_id'] ?? j['created_by']) as String?,
    );
  }
}
