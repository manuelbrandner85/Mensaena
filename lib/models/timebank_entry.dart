class TimebankEntry {
  final String id;
  final String giverId;
  final String receiverId;
  final String? postId;
  final double hours;
  final String? description;
  final String? category;
  final String status;
  final DateTime? confirmedAt;
  final DateTime? helpDate;
  final DateTime createdAt;

  // Joined
  final Map<String, dynamic>? giverProfile;
  final Map<String, dynamic>? receiverProfile;

  const TimebankEntry({
    required this.id,
    required this.giverId,
    required this.receiverId,
    this.postId,
    required this.hours,
    this.description,
    this.category,
    this.status = 'pending',
    this.confirmedAt,
    this.helpDate,
    required this.createdAt,
    this.giverProfile,
    this.receiverProfile,
  });

  factory TimebankEntry.fromJson(Map<String, dynamic> json) {
    return TimebankEntry(
      id: json['id'] as String,
      giverId: json['giver_id'] as String,
      receiverId: json['receiver_id'] as String,
      postId: json['post_id'] as String?,
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'pending',
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      helpDate: json['help_date'] != null
          ? DateTime.parse(json['help_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      giverProfile: json['giver'] as Map<String, dynamic>?,
      receiverProfile: json['receiver'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'giver_id': giverId,
      'receiver_id': receiverId,
      'post_id': postId,
      'hours': hours,
      'description': description,
      'category': category,
      'status': status,
      'help_date': helpDate?.toIso8601String().split('T')[0],
    };
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
}
