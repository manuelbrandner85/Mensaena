class Thanks {
  const Thanks({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.emoji,
    this.postId,
    this.message,
    this.createdAt,
    this.fromName,
    this.fromAvatarUrl,
    this.toName,
    this.toAvatarUrl,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String emoji;
  final String? postId;
  final String? message;
  final DateTime? createdAt;
  final String? fromName;
  final String? fromAvatarUrl;
  final String? toName;
  final String? toAvatarUrl;

  factory Thanks.fromJson(Map<String, dynamic> j) {
    // Joins koennen unter aliassen kommen: from_profile / to_profile oder als
    // verschachtelte profiles-Map mit role discriminator. Wir lesen tolerant.
    Map<String, dynamic>? fromProfile = j['from_profile'] as Map<String, dynamic>?;
    Map<String, dynamic>? toProfile = j['to_profile'] as Map<String, dynamic>?;
    fromProfile ??= j['from_user'] as Map<String, dynamic>?;
    toProfile ??= j['to_user'] as Map<String, dynamic>?;

    return Thanks(
      id: j['id'] as String,
      fromUserId: j['from_user_id'] as String? ?? '',
      toUserId: j['to_user_id'] as String? ?? '',
      emoji: j['emoji'] as String? ?? '',
      postId: j['post_id'] as String?,
      message: j['message'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      fromName: fromProfile?['name'] as String? ??
          fromProfile?['display_name'] as String?,
      fromAvatarUrl: fromProfile?['avatar_url'] as String?,
      toName: toProfile?['name'] as String? ??
          toProfile?['display_name'] as String?,
      toAvatarUrl: toProfile?['avatar_url'] as String?,
    );
  }
}
