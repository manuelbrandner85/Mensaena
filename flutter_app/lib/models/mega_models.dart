/// SKILL: mensaena-features + supabase
/// Models für Phase-2-12 Mega-Features. Spiegelt neue DB-Tabellen.
library;

class Story {
  const Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.textOverlay,
    required this.expiresAt,
    this.viewCount = 0,
    required this.createdAt,
    this.authorName,
    this.authorAvatar,
  });

  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType;
  final String? textOverlay;
  final DateTime expiresAt;
  final int viewCount;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatar;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  Duration get remaining => expiresAt.difference(DateTime.now());

  factory Story.fromJson(Map<String, dynamic> j) {
    String? name;
    String? avatar;
    final author = j['author'];
    if (author is Map) {
      name = (author['display_name'] ?? author['name']) as String?;
      avatar = author['avatar_url'] as String?;
    }
    return Story(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      mediaUrl: j['media_url'] as String? ?? '',
      mediaType: j['media_type'] as String? ?? 'image',
      textOverlay: j['text_overlay'] as String?,
      expiresAt:
          DateTime.tryParse(j['expires_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      authorName: name,
      authorAvatar: avatar,
    );
  }
}

class UserFollow {
  const UserFollow({
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  factory UserFollow.fromJson(Map<String, dynamic> j) => UserFollow(
        followerId: j['follower_id'] as String,
        followingId: j['following_id'] as String,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      );
}

class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.userId,
    required this.challengeType,
    required this.challengeText,
    this.karmaReward = 5,
    this.isCompleted = false,
    this.completedAt,
    required this.date,
  });

  final String id;
  final String userId;
  final String challengeType;
  final String challengeText;
  final int karmaReward;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime date;

  factory DailyChallenge.fromJson(Map<String, dynamic> j) => DailyChallenge(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        challengeType: j['challenge_type'] as String? ?? '',
        challengeText: j['challenge_text'] as String? ?? '',
        karmaReward: (j['karma_reward'] as num?)?.toInt() ?? 5,
        isCompleted: (j['is_completed'] as bool?) ?? false,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)?.toUtc()
            : null,
        date: DateTime.tryParse(j['date'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      );
}

class ThankYouCard {
  const ThankYouCard({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.interactionId,
    this.designId = 1,
    this.message,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String? interactionId;
  final int designId;
  final String? message;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  factory ThankYouCard.fromJson(Map<String, dynamic> j) {
    String? name;
    String? avatar;
    final s = j['sender'];
    if (s is Map) {
      name = (s['display_name'] ?? s['name']) as String?;
      avatar = s['avatar_url'] as String?;
    }
    return ThankYouCard(
      id: j['id'] as String,
      senderId: j['sender_id'] as String,
      receiverId: j['receiver_id'] as String,
      interactionId: j['interaction_id'] as String?,
      designId: (j['design_id'] as num?)?.toInt() ?? 1,
      message: j['message'] as String?,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      senderName: name,
      senderAvatar: avatar,
    );
  }
}

class CommunityPoll {
  const CommunityPoll({
    required this.id,
    required this.creatorId,
    required this.question,
    required this.options,
    this.isAnonymous = false,
    this.closesAt,
    this.status = 'active',
    required this.createdAt,
    this.creatorName,
  });

  final String id;
  final String creatorId;
  final String question;
  final List<String> options;
  final bool isAnonymous;
  final DateTime? closesAt;
  final String status;
  final DateTime createdAt;
  final String? creatorName;

  bool get isClosed =>
      status != 'active' ||
      (closesAt != null && closesAt!.isBefore(DateTime.now()));

  factory CommunityPoll.fromJson(Map<String, dynamic> j) {
    final opts = j['options'];
    final list = opts is List
        ? opts.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    String? name;
    final c = j['creator'];
    if (c is Map) {
      name = (c['display_name'] ?? c['name']) as String?;
    }
    return CommunityPoll(
      id: j['id'] as String,
      creatorId: j['creator_id'] as String,
      question: j['question'] as String? ?? '',
      options: list,
      isAnonymous: (j['is_anonymous'] as bool?) ?? false,
      closesAt: j['closes_at'] != null
          ? DateTime.tryParse(j['closes_at'] as String)?.toUtc()
          : null,
      status: j['status'] as String? ?? 'active',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      creatorName: name,
    );
  }
}

class Mentorship {
  const Mentorship({
    required this.id,
    required this.mentorId,
    required this.menteeId,
    this.status = 'active',
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String mentorId;
  final String menteeId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;

  factory Mentorship.fromJson(Map<String, dynamic> j) => Mentorship(
        id: j['id'] as String,
        mentorId: j['mentor_id'] as String,
        menteeId: j['mentee_id'] as String,
        status: j['status'] as String? ?? 'active',
        startedAt:
            DateTime.tryParse(j['started_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
        endedAt: j['ended_at'] != null
            ? DateTime.tryParse(j['ended_at'] as String)?.toUtc()
            : null,
      );
}

class LivestreamMessage {
  const LivestreamMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    this.type = 'text',
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final String type;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  factory LivestreamMessage.fromJson(Map<String, dynamic> j) {
    String? name;
    String? avatar;
    final u = j['author'];
    if (u is Map) {
      name = (u['display_name'] ?? u['name']) as String?;
      avatar = u['avatar_url'] as String?;
    }
    return LivestreamMessage(
      id: j['id'] as String,
      roomId: j['room_id'] as String,
      userId: j['user_id'] as String,
      content: j['content'] as String? ?? '',
      type: j['type'] as String? ?? 'text',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ?? DateTime.now(),
      userName: name,
      userAvatar: avatar,
    );
  }
}

class CommunityPollVote {
  const CommunityPollVote({
    required this.pollId,
    required this.userId,
    required this.optionIndex,
  });
  final String pollId;
  final String userId;
  final int optionIndex;

  factory CommunityPollVote.fromJson(Map<String, dynamic> j) =>
      CommunityPollVote(
        pollId: j['poll_id'] as String,
        userId: j['user_id'] as String,
        optionIndex: (j['option_index'] as num?)?.toInt() ?? 0,
      );
}
