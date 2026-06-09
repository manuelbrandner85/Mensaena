/// SKILL: mensaena-features + supabase
/// Spiegel von post_contact_requests inkl. optionaler JOIN-Daten
/// fuer requester-Profil + Post-Titel.
library;

class PostContactRequest {
  const PostContactRequest({
    required this.id,
    required this.postId,
    required this.requesterId,
    required this.postOwnerId,
    required this.contactMethod,
    required this.status,
    this.message,
    this.respondedAt,
    required this.createdAt,
    this.requesterName,
    this.requesterAvatar,
    this.postTitle,
  });

  final String id;
  final String postId;
  final String requesterId;
  final String postOwnerId;

  /// 'in_app_chat'|'phone'|'email'|'whatsapp'|'location_meetup'
  final String contactMethod;

  /// 'pending'|'accepted'|'declined'|'completed'|'expired'
  final String status;
  final String? message;
  final DateTime? respondedAt;
  final DateTime createdAt;

  final String? requesterName;
  final String? requesterAvatar;
  final String? postTitle;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCompleted => status == 'completed';

  factory PostContactRequest.fromJson(Map<String, dynamic> j) {
    // Optionaler embedded JOIN aus PostgREST select=..., requester:profiles(...)
    String? rName;
    String? rAvatar;
    final requester = j['requester'];
    if (requester is Map) {
      rName = (requester['display_name'] ?? requester['name']) as String?;
      rAvatar = requester['avatar_url'] as String?;
    }
    String? pTitle;
    final post = j['post'];
    if (post is Map) {
      pTitle = post['title'] as String?;
    }

    return PostContactRequest(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      requesterId: j['requester_id'] as String,
      postOwnerId: j['post_owner_id'] as String,
      contactMethod: j['contact_method'] as String,
      status: j['status'] as String? ?? 'pending',
      message: j['message'] as String?,
      respondedAt: j['responded_at'] != null
          ? DateTime.tryParse(j['responded_at'] as String)?.toUtc()
          : null,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ??
              DateTime.now(),
      requesterName: rName,
      requesterAvatar: rAvatar,
      postTitle: pTitle,
    );
  }
}
