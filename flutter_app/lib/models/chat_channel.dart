/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `chat_channels` (gyqujitkvymlmgroovch).
class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    this.description,
    this.emoji,
    this.isDefault,
    this.isLocked,
    this.lockedBy,
    this.lockedAt,
    this.lockedReason,
    this.sortOrder,
    this.createdAt,
    this.conversationId,
    this.avatarUrl,
    this.bannerUrl,
  });

  final String id;
  final String name;
  final String? description;
  final String? emoji;
  final String slug;
  final bool? isDefault;
  final bool? isLocked;
  final String? lockedBy;
  final DateTime? lockedAt;
  final String? lockedReason;
  final int? sortOrder;
  final DateTime? createdAt;
  final String? conversationId;
  final String category;
  final String? avatarUrl;
  final String? bannerUrl;

  factory ChatChannel.fromJson(Map<String, dynamic> j) {
    return ChatChannel(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      emoji: j['emoji'] as String?,
      slug: j['slug'] as String? ?? '',
      isDefault: j['is_default'] as bool?,
      isLocked: j['is_locked'] as bool?,
      lockedBy: j['locked_by'] as String?,
      lockedAt: j['locked_at'] != null
          ? DateTime.tryParse(j['locked_at'] as String)?.toUtc()
          : null,
      lockedReason: j['locked_reason'] as String?,
      sortOrder: (j['sort_order'] as num?)?.toInt(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
      conversationId: j['conversation_id'] as String?,
      category: j['category'] as String? ?? '',
      avatarUrl: j['avatar_url'] as String?,
      bannerUrl: j['banner_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'slug': slug,
        'is_default': isDefault,
        'is_locked': isLocked,
        'locked_by': lockedBy,
        'locked_at': lockedAt?.toIso8601String(),
        'locked_reason': lockedReason,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
        'conversation_id': conversationId,
        'category': category,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
      };
}
