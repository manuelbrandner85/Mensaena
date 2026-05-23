/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `organization_reviews` (huaqldjkgyosefzfhjnf).
class OrganizationReview {
  const OrganizationReview({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.rating,
    required this.content,
    this.title,
    this.helpfulCount = 0,
    this.isFlagged = false,
    this.adminResponse,
    this.adminRespondedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String userId;
  final int rating;
  final String content;
  final String? title;
  final int helpfulCount;
  final bool isFlagged;
  final String? adminResponse;
  final DateTime? adminRespondedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrganizationReview.fromJson(Map<String, dynamic> j) {
    return OrganizationReview(
      id: j['id'] as String,
      organizationId: j['organization_id'] as String,
      userId: j['user_id'] as String,
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      content: j['content'] as String,
      title: j['title'] as String?,
      helpfulCount: (j['helpful_count'] as num?)?.toInt() ?? 0,
      isFlagged: (j['is_flagged'] as bool?) ?? false,
      adminResponse: j['admin_response'] as String?,
      adminRespondedAt: j['admin_responded_at'] != null
          ? DateTime.tryParse(j['admin_responded_at'] as String)
          : null,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'user_id': userId,
        'rating': rating,
        'content': content,
        'title': title,
        'helpful_count': helpfulCount,
        'is_flagged': isFlagged,
        'admin_response': adminResponse,
        'admin_responded_at': adminRespondedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
