enum InteractionStatus {
  requested('requested', 'Angefragt'),
  accepted('accepted', 'Angenommen'),
  inProgress('in_progress', 'Aktiv'),
  completed('completed', 'Abgeschlossen'),
  cancelledByHelper('cancelled_by_helper', 'Vom Helfer abgebrochen'),
  cancelledByHelped('cancelled_by_helped', 'Vom Hilfesuchenden abgebrochen'),
  disputed('disputed', 'Streitfall'),
  resolved('resolved', 'Geklärt');

  const InteractionStatus(this.value, this.label);
  final String value;
  final String label;

  static InteractionStatus fromString(String value) {
    return InteractionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InteractionStatus.requested,
    );
  }
}

class Interaction {
  final String id;
  final String postId;
  final String helperId;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  // Joined
  final Map<String, dynamic>? helperProfile;
  final Map<String, dynamic>? post;
  final Map<String, dynamic>? postOwnerProfile;

  const Interaction({
    required this.id,
    required this.postId,
    required this.helperId,
    this.status = 'requested',
    this.message,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.helperProfile,
    this.post,
    this.postOwnerProfile,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      helperId: json['helper_id'] as String,
      status: json['status'] as String? ?? 'requested',
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      helperProfile: json['helper_profile'] as Map<String, dynamic>? ??
          json['profiles'] as Map<String, dynamic>?,
      post: json['posts'] as Map<String, dynamic>?,
      postOwnerProfile: json['post_owner_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'helper_id': helperId,
      'status': status,
      'message': message,
    };
  }

  InteractionStatus get interactionStatus =>
      InteractionStatus.fromString(status);
}
