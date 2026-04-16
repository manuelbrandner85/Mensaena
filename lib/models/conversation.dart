class Conversation {
  final String id;
  final String type; // 'direct', 'group', 'system'
  final String? title;
  final String? postId;
  final bool isLocked;
  final String? lockedBy;
  final DateTime? lockedAt;
  final String? lockedReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final List<ConversationMember>? members;
  final Message? lastMessage;
  final int? unreadCount;

  const Conversation({
    required this.id,
    required this.type,
    this.title,
    this.postId,
    this.isLocked = false,
    this.lockedBy,
    this.lockedAt,
    this.lockedReason,
    required this.createdAt,
    required this.updatedAt,
    this.members,
    this.lastMessage,
    this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'direct',
      title: json['title'] as String?,
      postId: json['post_id'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
      lockedBy: json['locked_by'] as String?,
      lockedAt: json['locked_at'] != null
          ? DateTime.parse(json['locked_at'] as String)
          : null,
      lockedReason: json['locked_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'post_id': postId,
      'is_locked': isLocked,
    };
  }
}

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime? lastReadAt;
  final String role; // 'owner', 'admin', 'member'
  final DateTime createdAt;

  // Joined
  final Map<String, dynamic>? profile;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.lastReadAt,
    this.role = 'member',
    required this.createdAt,
    this.profile,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
      role: json['role'] as String? ?? 'member',
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? receiverId;
  final String content;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final String? replyToId;
  final DateTime? editedAt;
  final bool isPinned;

  // Joined
  final Map<String, dynamic>? senderProfile;
  final List<MessageReaction>? reactions;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    required this.content,
    required this.createdAt,
    this.deletedAt,
    this.replyToId,
    this.editedAt,
    this.isPinned = false,
    this.senderProfile,
    this.reactions,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      replyToId: json['reply_to_id'] as String?,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      senderProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'reply_to_id': replyToId,
    };
  }

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;

  String get senderName {
    if (senderProfile == null) return 'Unbekannt';
    return senderProfile!['nickname'] as String? ??
        senderProfile!['name'] as String? ??
        'Unbekannt';
  }
}

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;

  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
    );
  }
}
