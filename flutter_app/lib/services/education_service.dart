/// SKILL: mensaena-features
/// EducationService (V11) — reader for the `knowledge_articles` table.
///
/// Surfaces published, long-form learning content (articles, guides,
/// explainers) for the Knowledge / Wiki hub. Writes happen elsewhere
/// (`KnowledgeCreateScreen`) — this service is read-only.
///
/// Schema reference: see `lib/models/knowledge_article.dart`.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class EducationContent {
  const EducationContent({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.category,
    this.sourceUrl,
    this.summary,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? category;

  /// External reference (e.g. citation / further reading). `knowledge_articles`
  /// does not have a dedicated `source_url` column today — we fall back to a
  /// canonical `mensaena.de/wissen/<slug>` URL when none is present.
  final String? sourceUrl;
  final String? summary;
  final String? imageUrl;

  factory EducationContent.fromJson(Map<String, dynamic> j) {
    final slug = j['slug']?.toString();
    return EducationContent(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      body: j['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ??
              DateTime.now(),
      category: j['category']?.toString(),
      sourceUrl: j['source_url']?.toString() ??
          (slug != null && slug.isNotEmpty
              ? 'https://www.mensaena.de/wissen/$slug'
              : null),
      summary: j['summary']?.toString(),
      imageUrl: j['image_url']?.toString(),
    );
  }
}

class EducationService {
  const EducationService._();

  /// Lists published articles, newest first. Pass [category] to filter by
  /// the `category` column. Returns an empty list on error so callers can
  /// render an empty state without crashing.
  static Future<List<EducationContent>> list({
    String? category,
    int limit = 20,
  }) async {
    try {
      final query = SupabaseService.client
          .from('knowledge_articles')
          .select()
          .eq('status', 'published');

      final filtered =
          category != null ? query.eq('category', category) : query;

      final rows = await filtered
          .order('created_at', ascending: false)
          .limit(limit);

      // Supabase returns a List<dynamic>; narrow each row to the expected
      // shape before mapping into the model.
      return rows
          .whereType<Map<String, dynamic>>()
          .map(EducationContent.fromJson)
          .toList();
    } catch (e) {
      debugPrint('EducationService.list failed: $e');
      return const [];
    }
  }
}
