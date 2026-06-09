import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SKILL: mensaena-features
/// Draft-Persistence fuer Create-Post — Pendant zu Web localStorage-Drafts.
/// Speichert/laed Titel, Beschreibung, Typ, Ort, Tags zwischen App-Sessions.
class PostDraftService {
  const PostDraftService._();

  static const _key = 'create_post_draft_v1';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(PostDraft draft) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  static Future<PostDraft?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return PostDraft.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class PostDraft {
  const PostDraft({
    this.type,
    this.title = '',
    this.description = '',
    this.location = '',
    this.tags = '',
    this.savedAt,
  });

  final String? type;
  final String title;
  final String description;
  final String location;
  final String tags;
  final DateTime? savedAt;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'tags': tags,
        'saved_at': savedAt?.toIso8601String(),
      };

  factory PostDraft.fromJson(Map<String, dynamic> j) => PostDraft(
        type: j['type'] as String?,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        location: (j['location'] as String?) ?? '',
        tags: (j['tags'] as String?) ?? '',
        savedAt: j['saved_at'] != null
            ? DateTime.tryParse(j['saved_at'] as String)?.toUtc()
            : null,
      );

  bool get isEmpty =>
      title.isEmpty &&
      description.isEmpty &&
      location.isEmpty &&
      tags.isEmpty;
}
