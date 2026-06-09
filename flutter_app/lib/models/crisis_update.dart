/// SKILL: mensaena-architektur
/// Spiegel von `crisis_updates`. Live-Updates im Crisis-Detail-Feed.
class CrisisUpdate {
  const CrisisUpdate({
    required this.id,
    required this.crisisId,
    required this.authorId,
    required this.content,
    required this.updateType,
    this.imageUrl,
    this.isPinned = false,
    this.createdAt,
  });

  final String id;
  final String crisisId;
  final String authorId;
  final String content;
  final String updateType; // info | status_change | resource_update | helper_update | resolution | warning | official
  final String? imageUrl;
  final bool isPinned;
  final DateTime? createdAt;

  factory CrisisUpdate.fromJson(Map<String, dynamic> j) {
    return CrisisUpdate(
      id: j['id'] as String,
      crisisId: j['crisis_id'] as String,
      authorId: j['author_id'] as String,
      content: j['content'] as String? ?? '',
      updateType: j['update_type'] as String? ?? 'info',
      imageUrl: j['image_url'] as String?,
      isPinned: (j['is_pinned'] as bool?) ?? false,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
    );
  }
}
