class Group {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String creatorId;
  final bool isPrivate;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? creatorProfile;
  final bool? isMember;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    required this.creatorId,
    this.isPrivate = false,
    this.memberCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.creatorProfile,
    this.isMember,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      creatorId: json['creator_id'] as String,
      isPrivate: json['is_private'] as bool? ?? false,
      memberCount: json['member_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      creatorProfile: json['profiles'] as Map<String, dynamic>?,
      isMember: json['is_member'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'creator_id': creatorId,
      'is_private': isPrivate,
    };
  }
}

class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final Map<String, dynamic>? profile;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
    this.profile,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
