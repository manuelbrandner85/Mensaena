import '../messages/models.dart';

class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slug,
    required this.conversationId,
    this.description,
    this.isDefault = false,
    this.isLocked = false,
    this.lockedReason,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String emoji;
  final String slug;
  final bool isDefault;
  final bool isLocked;
  final String? lockedReason;
  final int sortOrder;
  final String conversationId;

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Allgemein',
        description: j['description'] as String?,
        emoji: j['emoji'] as String? ?? '💬',
        slug: j['slug'] as String? ?? 'allgemein',
        isDefault: j['is_default'] as bool? ?? false,
        isLocked: j['is_locked'] as bool? ?? false,
        lockedReason: j['locked_reason'] as String?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        conversationId: j['conversation_id'] as String,
      );
}

class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.userId,
    required this.messageId,
  });

  final String emoji;
  final String userId;
  final String messageId;

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        emoji: j['emoji'] as String,
        userId: j['user_id'] as String,
        messageId: j['message_id'] as String,
      );
}

class ReplyPreview {
  const ReplyPreview({required this.content, this.senderName});
  final String content;
  final String? senderName;
}

class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.deletedAt,
    this.editedAt,
    this.replyToId,
    this.senderProfile,
    this.reactions = const [],
    this.replyTo,
    this.isPinned = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final DateTime? editedAt;
  final String? replyToId;
  final Profile? senderProfile;
  final List<MessageReaction> reactions;
  final ReplyPreview? replyTo;
  final bool isPinned;

  bool get isDeleted => deletedAt != null;

  ChannelMessage copyWith({
    List<MessageReaction>? reactions,
    bool? isPinned,
  }) =>
      ChannelMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        deletedAt: deletedAt,
        editedAt: editedAt,
        replyToId: replyToId,
        senderProfile: senderProfile,
        reactions: reactions ?? this.reactions,
        replyTo: replyTo,
        isPinned: isPinned ?? this.isPinned,
      );

  factory ChannelMessage.fromJson(Map<String, dynamic> j) {
    final profileData = j['profiles'] as Map<String, dynamic>?;
    Profile? profile;
    if (profileData != null) {
      profile = Profile.fromJson(profileData);
    }

    final replyData = j['reply_to'] as Map<String, dynamic>?;
    ReplyPreview? replyTo;
    if (replyData != null) {
      final rp = replyData['profiles'] as Map<String, dynamic>?;
      replyTo = ReplyPreview(
        content: replyData['content'] as String? ?? '',
        senderName: rp?['name'] as String?,
      );
    }

    return ChannelMessage(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      senderId: j['sender_id'] as String,
      content: j['content'] as String? ?? '',
      createdAt: DateTime.parse(j['created_at'] as String),
      deletedAt: j['deleted_at'] != null ? DateTime.tryParse(j['deleted_at'] as String) : null,
      editedAt: j['edited_at'] != null ? DateTime.tryParse(j['edited_at'] as String) : null,
      replyToId: j['reply_to_id'] as String?,
      senderProfile: profile,
      replyTo: replyTo,
      isPinned: j['is_pinned'] as bool? ?? false,
    );
  }
}
