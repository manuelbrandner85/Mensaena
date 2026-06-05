/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `knowledge_articles` (gyqujitkvymlmgroovch).
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.authorId,
    required this.title,
    required this.slug,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.summary,
    this.category,
    this.tags = const [],
    this.imageUrl,
    this.views = 0,
    this.isPublic = true,
    this.isFeatured = false,
    this.status,
    this.publishedAt,
  });

  final String id;
  final String authorId;
  final String title;
  final String slug;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? summary;
  final String? category;
  final List<String> tags;
  final String? imageUrl;
  final int views;
  final bool isPublic;
  final bool isFeatured;
  final String? status;
  final DateTime? publishedAt;

  factory KnowledgeArticle.fromJson(Map<String, dynamic> j) {
    return KnowledgeArticle(
      id: j['id'] as String,
      authorId: j['author_id'] as String,
      title: j['title'] as String,
      slug: j['slug'] as String,
      content: j['content'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      summary: j['summary'] as String?,
      category: j['category'] as String?,
      tags: (j['tags'] is List)
          ? (j['tags'] as List).whereType<String>().toList()
          : const [],
      imageUrl: j['image_url'] as String?,
      views: (j['views'] as num?)?.toInt() ?? 0,
      isPublic: (j['is_public'] as bool?) ?? true,
      isFeatured: (j['is_featured'] as bool?) ?? false,
      status: j['status'] as String?,
      publishedAt: j['published_at'] != null
          ? DateTime.tryParse(j['published_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'title': title,
        'slug': slug,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'summary': summary,
        'category': category,
        'tags': tags,
        'image_url': imageUrl,
        'views': views,
        'is_public': isPublic,
        'is_featured': isFeatured,
        'status': status,
        'published_at': publishedAt?.toIso8601String(),
      };
}
