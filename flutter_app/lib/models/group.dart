/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `groups` (huaqldjkgyosefzfhjnf).
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.memberCount,
    required this.createdAt,
    this.description,
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
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isPrivate;
  final int postCount;
  final String? creatorId;

  factory Group.fromJson(Map<String, dynamic> j) {
    return Group(
      id: j['id'] as String,
      name: j['name'] as String,
      slug: j['slug'] as String,
      category: j['category'] as String,
      memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      description: j['description'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      bannerUrl: j['banner_url'] as String?,
      isPrivate: (j['is_private'] as bool?) ?? false,
      postCount: (j['post_count'] as num?)?.toInt() ?? 0,
      creatorId: j['creator_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'member_count': memberCount,
        'created_at': createdAt.toIso8601String(),
        'description': description,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
        'is_private': isPrivate,
        'post_count': postCount,
        'creator_id': creatorId,
      };
}
