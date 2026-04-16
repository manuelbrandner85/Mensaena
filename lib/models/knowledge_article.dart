class KnowledgeArticle {
  final String id;
  final String authorId;
  final String title;
  final String? slug;
  final String? content;
  final String? summary;
  final String? category;
  final List<String> tags;
  final String? imageUrl;
  final int views;
  final bool isPublic;
  final bool isFeatured;
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? authorProfile;

  const KnowledgeArticle({
    required this.id,
    required this.authorId,
    required this.title,
    this.slug,
    this.content,
    this.summary,
    this.category,
    this.tags = const [],
    this.imageUrl,
    this.views = 0,
    this.isPublic = true,
    this.isFeatured = false,
    this.status = 'draft',
    this.publishedAt,
    required this.createdAt,
    this.updatedAt,
    this.authorProfile,
  });

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticle(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String?,
      content: json['content'] as String?,
      summary: json['summary'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      imageUrl: json['image_url'] as String?,
      views: json['views'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      status: json['status'] as String? ?? 'draft',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      authorProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'title': title,
      'slug': slug,
      'content': content,
      'summary': summary,
      'category': category,
      'tags': tags,
      'image_url': imageUrl,
      'is_public': isPublic,
      'status': status,
    };
  }
}
