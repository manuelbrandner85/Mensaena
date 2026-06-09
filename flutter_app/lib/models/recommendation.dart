/// Spiegel der Supabase-Tabelle `recommendations`.
///
/// Ziel ist entweder ein Nutzer ([targetUserId]), eine Organisation
/// ([targetOrgId]) oder ein reiner Freitext-Name ([targetName]).
/// Genau eines dieser drei Felder ist gesetzt (DB-Constraint).
class Recommendation {
  const Recommendation({
    required this.id,
    required this.authorId,
    required this.category,
    required this.text,
    required this.stars,
    required this.createdAt,
    this.targetUserId,
    this.targetOrgId,
    this.targetName,
    this.photoUrls = const [],
    this.isPublic = true,
    this.isFlagged = false,
    this.updatedAt,
    // Joined fields
    this.authorName,
    this.authorAvatarUrl,
    this.authorDisplayName,
    this.targetDisplayName,
    this.targetAvatarUrl,
  });

  final String id;
  final String authorId;

  final String? targetUserId;
  final String? targetOrgId;
  final String? targetName;

  final String category;
  final String text;

  /// Sterne-Bewertung 1–5.
  final int stars;

  final List<String> photoUrls;
  final bool isPublic;
  final bool isFlagged;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Profile-Join Autor
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorDisplayName;

  // Ziel-Profil oder Organisations-Name (Join)
  final String? targetDisplayName;
  final String? targetAvatarUrl;

  static const List<String> categories = [
    'general',
    'handcraft',
    'garden',
    'cleaning',
    'cooking',
    'care',
    'transport',
    'tech',
    'pets',
    'shopping',
    'tutoring',
    'other',
  ];

  factory Recommendation.fromJson(Map<String, dynamic> j) {
    final authorProfiles = j['author_profiles'] as Map<String, dynamic>?
        ?? j['profiles']         as Map<String, dynamic>?;
    final targetProfiles = j['target_profiles'] as Map<String, dynamic>?;
    final targetOrg = j['organizations']      as Map<String, dynamic>?;

    return Recommendation(
      id:           j['id']          as String,
      authorId:     j['author_id']   as String,
      targetUserId: j['target_user_id'] as String?,
      targetOrgId:  j['target_org_id']  as String?,
      targetName:   j['target_name']    as String?,
      category:     (j['category'] as String?) ?? 'general',
      text:         (j['text']     as String?) ?? '',
      stars:        (j['stars']    as num?)?.toInt() ?? 1,
      photoUrls: (j['photo_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPublic:   (j['is_public']  as bool?) ?? true,
      isFlagged:  (j['is_flagged'] as bool?) ?? false,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)?.toUtc()
          : null,
      authorName:        authorProfiles?['name']         as String?,
      authorAvatarUrl:   authorProfiles?['avatar_url']   as String?,
      authorDisplayName: authorProfiles?['display_name'] as String?,
      targetDisplayName: (targetProfiles?['display_name']
          ?? targetProfiles?['name']
          ?? targetOrg?['name']) as String?,
      targetAvatarUrl: (targetProfiles?['avatar_url']
          ?? targetOrg?['logo_url']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'author_id':      authorId,
        'target_user_id': targetUserId,
        'target_org_id':  targetOrgId,
        'target_name':    targetName,
        'category':       category,
        'text':           text,
        'stars':          stars,
        'photo_urls':     photoUrls,
        'is_public':      isPublic,
        'is_flagged':     isFlagged,
        'created_at':     createdAt.toIso8601String(),
        'updated_at':     updatedAt?.toIso8601String(),
      };

  Recommendation copyWith({
    String? category,
    String? text,
    int? stars,
    List<String>? photoUrls,
    bool? isPublic,
    bool? isFlagged,
  }) =>
      Recommendation(
        id:               id,
        authorId:         authorId,
        targetUserId:     targetUserId,
        targetOrgId:      targetOrgId,
        targetName:       targetName,
        category:         category ?? this.category,
        text:             text     ?? this.text,
        stars:            stars    ?? this.stars,
        photoUrls:        photoUrls ?? this.photoUrls,
        isPublic:         isPublic  ?? this.isPublic,
        isFlagged:        isFlagged ?? this.isFlagged,
        createdAt:        createdAt,
        updatedAt:        updatedAt,
        authorName:       authorName,
        authorAvatarUrl:  authorAvatarUrl,
        authorDisplayName: authorDisplayName,
        targetDisplayName: targetDisplayName,
        targetAvatarUrl:   targetAvatarUrl,
      );
}
