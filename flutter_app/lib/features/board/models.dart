import 'package:flutter/material.dart';

class BoardCategoryConfig {
  const BoardCategoryConfig({
    required this.value,
    required this.label,
    required this.emoji,
  });
  final String value;
  final String label;
  final String emoji;

  static const all = <BoardCategoryConfig>[
    BoardCategoryConfig(value: 'general', label: 'Allgemein', emoji: '📌'),
    BoardCategoryConfig(value: 'gesucht', label: 'Gesucht', emoji: '🔍'),
    BoardCategoryConfig(value: 'biete', label: 'Biete', emoji: '🎁'),
    BoardCategoryConfig(value: 'event', label: 'Veranstaltung', emoji: '📅'),
    BoardCategoryConfig(value: 'info', label: 'Info', emoji: 'ℹ️'),
    BoardCategoryConfig(value: 'warnung', label: 'Warnung', emoji: '⚠️'),
    BoardCategoryConfig(value: 'verloren', label: 'Verloren', emoji: '😢'),
    BoardCategoryConfig(value: 'fundbuero', label: 'Fundbüro', emoji: '🔑'),
  ];

  static BoardCategoryConfig forValue(String? v) {
    for (final c in all) {
      if (c.value == v) return c;
    }
    return all.first;
  }
}

class BoardColors {
  const BoardColors._();

  static ({Color bg, Color border, Color text}) forName(String? name) {
    switch (name) {
      case 'yellow':
        return (
          bg: const Color(0xFFFEF9C3),
          border: const Color(0xFFFDE047),
          text: const Color(0xFF713F12),
        );
      case 'green':
        return (
          bg: const Color(0xFFDCFCE7),
          border: const Color(0xFF86EFAC),
          text: const Color(0xFF14532D),
        );
      case 'blue':
        return (
          bg: const Color(0xFFDBEAFE),
          border: const Color(0xFF93C5FD),
          text: const Color(0xFF1E3A8A),
        );
      case 'pink':
        return (
          bg: const Color(0xFFFCE7F3),
          border: const Color(0xFFF9A8D4),
          text: const Color(0xFF831843),
        );
      case 'orange':
        return (
          bg: const Color(0xFFFFEDD5),
          border: const Color(0xFFFDBA74),
          text: const Color(0xFF7C2D12),
        );
      case 'purple':
        return (
          bg: const Color(0xFFF3E8FF),
          border: const Color(0xFFD8B4FE),
          text: const Color(0xFF581C87),
        );
      default:
        return (
          bg: const Color(0xFFFEF9C3),
          border: const Color(0xFFFDE047),
          text: const Color(0xFF713F12),
        );
    }
  }
}

class BoardPost {
  const BoardPost({
    required this.id,
    required this.authorId,
    required this.content,
    required this.category,
    required this.color,
    required this.pinned,
    required this.createdAt,
    this.imageUrl,
    this.contactInfo,
    this.expiresAt,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final String content;
  final String category;
  final String color;
  final bool pinned;
  final DateTime createdAt;
  final String? imageUrl;
  final String? contactInfo;
  final DateTime? expiresAt;
  final String? authorName;
  final String? authorAvatarUrl;

  BoardCategoryConfig get categoryConfig => BoardCategoryConfig.forValue(category);

  factory BoardPost.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return BoardPost(
      id: j['id'] as String,
      authorId: j['author_id'] as String? ?? '',
      content: j['content'] as String? ?? '',
      category: j['category'] as String? ?? 'general',
      color: j['color'] as String? ?? 'yellow',
      pinned: j['pinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      imageUrl: j['image_url'] as String?,
      contactInfo: j['contact_info'] as String?,
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'] as String)
          : null,
      authorName: profile?['name'] as String? ?? profile?['display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
