/// SKILL: mensaena-features + supabase
/// Helper-Repository fuer das Knowledge-/Wiki-Modul (knowledge_articles):
/// Liste (Bildung vs. Wiki), Veröffentlichen, Lese-Tracking, Image-Upload.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_article.dart';
import '../services/supabase_service.dart';

class KnowledgeRepository {
  const KnowledgeRepository._();

  /// Edukations-Kategorien — trennen „Bildung" (/dashboard/knowledge)
  /// vom „Wiki" (/dashboard/wiki), das den Rest zeigt.
  static const eduCategories = [
    'kurs', 'workshop', 'tutorial', 'lernmaterial', 'webinar', 'anleitung',
  ];

  /// Öffentliche Artikel, gefiltert nach Bereich. [edu]=true → nur
  /// Edukations-Kategorien, false → alle anderen. Featured zuerst.
  static Future<List<KnowledgeArticle>> listPublic({
    required bool edu,
    int limit = 200,
  }) async {
    try {
      var q = sb.from('knowledge_articles').select().eq('is_public', true);
      if (edu) {
        q = q.inFilter('category', eduCategories);
      } else {
        q = q.not('category', 'in',
            '(${eduCategories.map((c) => '"$c"').join(',')})');
      }
      final rows = await q
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeArticle.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Artikel veröffentlichen. Gibt true bei Erfolg.
  static Future<bool> publish({
    required String title,
    required String slug,
    required String content,
    String? summary,
    required String category,
    List<String> tags = const [],
    String? imageUrl,
    bool isPublic = true,
    bool isFeatured = false,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('knowledge_articles').insert({
        'author_id': uid,
        'title': title,
        'slug': slug,
        'content': content,
        'summary': (summary != null && summary.isNotEmpty) ? summary : null,
        'category': category,
        'tags': tags,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_public': isPublic,
        'is_featured': isFeatured,
        'status': 'published',
        'published_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lese-Fortschritt fest-/nachhalten (fire-and-forget, fehlertolerant).
  static Future<void> recordRead(String articleId, {int scrollPct = 0}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('knowledge_article_reads').upsert({
        'article_id': articleId,
        'user_id': uid,
        'scroll_pct': scrollPct,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'article_id,user_id');
    } catch (_) {/* tracking ist optional */}
  }

  /// Upload eines Cover-Bildes zu Supabase Storage. Vorher: silently auf
  /// 'chat-images' gefallen, jetzt: nur 'knowledge-images' (Bucket wurde
  /// in Migration 20260602120000 angelegt).
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String userId,
    required String fileExt, // 'jpg' | 'png' | 'webp'
  }) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '$userId/$filename';
    try {
      await sb.storage.from('knowledge-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      return sb.storage.from('knowledge-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadKnowledgeImage failed: $e');
      return null;
    }
  }
}
