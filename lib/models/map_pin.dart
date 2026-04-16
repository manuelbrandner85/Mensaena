class MapPin {
  final String id;
  final double latitude;
  final double longitude;
  final String type;
  final String title;
  final String? description;
  final String? locationText;
  final String? imageUrl;
  final String? userId;
  final String? userName;
  final String? userAvatar;
  final DateTime? createdAt;
  final String? status;

  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.title,
    this.description,
    this.locationText,
    this.imageUrl,
    this.userId,
    this.userName,
    this.userAvatar,
    this.createdAt,
    this.status,
  });

  factory MapPin.fromPost(Map<String, dynamic> json) {
    return MapPin(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: json['type'] as String? ?? 'help_needed',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      locationText: json['location_text'] as String?,
      imageUrl: json['image_url'] as String?,
      userId: json['user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      status: json['status'] as String?,
    );
  }

  factory MapPin.fromOrganization(Map<String, dynamic> json) {
    return MapPin(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: 'organization',
      title: json['name'] as String? ?? '',
      description: json['description'] as String?,
      locationText: json['city'] as String?,
    );
  }
}
