/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `organization_reviews` (gyqujitkvymlmgroovch).
///
/// DB-Spalten-Namen sind exakt: `content`, `is_flagged`, `admin_responded_at`.
/// Die Felder hier heissen `content`, `isReported` (kompatibel zur UI),
/// `adminResponseAt`. Profile-Join via `profiles:user_id(name, avatar_url,
/// display_name)` liefert `userName`, `userAvatarUrl`, `userDisplayName`.
class OrganizationReview {
  const OrganizationReview({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.rating,
    required this.content,
    required this.createdAt,
    this.title,
    this.helpfulCount = 0,
    this.isReported = false,
    this.reportReason,
    this.adminResponse,
    this.adminResponseAt,
    this.userName,
    this.userAvatarUrl,
    this.userDisplayName,
    this.userFoundHelpful = false,
  });

  final String id;
  final String organizationId;
  final String userId;
  final int rating;
  final String content;
  final String? title;
  final int helpfulCount;
  final bool isReported;
  final String? reportReason;
  final String? adminResponse;
  final DateTime? adminResponseAt;
  final DateTime createdAt;

  // Profile-Join + Client-State
  final String? userName;
  final String? userAvatarUrl;
  final String? userDisplayName;
  final bool userFoundHelpful;

  factory OrganizationReview.fromJson(Map<String, dynamic> j) {
    final profiles = j['profiles'] as Map<String, dynamic>?;
    return OrganizationReview(
      id: j['id'] as String,
      organizationId: j['organization_id'] as String,
      userId: j['user_id'] as String,
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      title: j['title'] as String?,
      content: (j['content'] ?? j['comment'] ?? '') as String,
      helpfulCount: (j['helpful_count'] as num?)?.toInt() ?? 0,
      isReported: (j['is_flagged'] as bool?) ??
          (j['is_reported'] as bool?) ??
          false,
      reportReason: j['report_reason'] as String?,
      adminResponse: j['admin_response'] as String?,
      adminResponseAt: DateTime.tryParse(
          (j['admin_responded_at'] ?? j['admin_response_at'] ?? '') as String),
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      userName: profiles?['name'] as String?,
      userAvatarUrl: profiles?['avatar_url'] as String?,
      userDisplayName: profiles?['display_name'] as String?,
      userFoundHelpful: false,
    );
  }

  OrganizationReview copyWith({
    int? helpfulCount,
    bool? userFoundHelpful,
  }) =>
      OrganizationReview(
        id: id,
        organizationId: organizationId,
        userId: userId,
        rating: rating,
        content: content,
        createdAt: createdAt,
        title: title,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        isReported: isReported,
        reportReason: reportReason,
        adminResponse: adminResponse,
        adminResponseAt: adminResponseAt,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        userDisplayName: userDisplayName,
        userFoundHelpful: userFoundHelpful ?? this.userFoundHelpful,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'user_id': userId,
        'rating': rating,
        'title': title,
        'content': content,
        'helpful_count': helpfulCount,
        'is_flagged': isReported,
        'report_reason': reportReason,
        'admin_response': adminResponse,
        'admin_responded_at': adminResponseAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
