// Datenmodelle für DMs/Chat – matched das Supabase-Schema 1:1.
// Tabellen: conversations, conversation_members, messages.

class Profile {
  const Profile({required this.id, this.name, this.avatarUrl});
  final String id;
  final String? name;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  String displayName() => name ?? 'Unbekannt';
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    this.title,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.otherProfile,
  });

  final String id;
  final String type; // 'direct' | 'group' | 'system'
  final String? title;
  final DateTime createdAt;
  final Message? lastMessage;
  final int unreadCount;
  final Profile? otherProfile; // Bei direct: das Gegenüber

  bool get isDirect => type == 'direct';

  String displayTitle() {
    if (title != null && title!.isNotEmpty) return title!;
    if (otherProfile != null) return otherProfile!.displayName();
    return 'Gespräch';
  }

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        type: (json['type'] as String?) ?? 'direct',
        title: json['title'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Conversation copyWith({
    Message? lastMessage,
    int? unreadCount,
    Profile? otherProfile,
  }) =>
      Conversation(
        id: id,
        type: type,
        title: title,
        createdAt: createdAt,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        otherProfile: otherProfile ?? this.otherProfile,
      );
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.deletedAt,
    this.senderProfile,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final Profile? senderProfile;

  bool get isDeleted => deletedAt != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    Profile? sender;
    final p = json['profiles'] ?? json['sender'];
    if (p is Map<String, dynamic>) sender = Profile.fromJson(p);
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
      deletedAt:
          json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
      senderProfile: sender,
    );
  }
}
