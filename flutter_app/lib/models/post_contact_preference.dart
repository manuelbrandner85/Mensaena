/// SKILL: mensaena-features + supabase
/// Spiegel von post_contact_preferences: was Post-Ersteller als Kontaktwege
/// zulaesst, plus konkrete Daten (Telefon, E-Mail, WhatsApp, Treffpunkt).
library;

class PostContactPreference {
  const PostContactPreference({
    this.id,
    required this.postId,
    required this.userId,
    this.allowInAppChat = true,
    this.allowPhone = false,
    this.allowEmail = false,
    this.allowWhatsapp = false,
    this.allowLocationMeetup = false,
    this.phoneNumber,
    this.emailAddress,
    this.whatsappNumber,
    this.meetupNote,
    this.availableFrom,
    this.availableUntil,
    this.availableDays,
    this.contactNote,
  });

  final String? id;
  final String postId;
  final String userId;
  final bool allowInAppChat;
  final bool allowPhone;
  final bool allowEmail;
  final bool allowWhatsapp;
  final bool allowLocationMeetup;
  final String? phoneNumber;
  final String? emailAddress;
  final String? whatsappNumber;
  final String? meetupNote;

  /// 'HH:mm:ss' Postgres TIME.
  final String? availableFrom;
  final String? availableUntil;

  /// z. B. ['Mo','Di','Mi','Do','Fr','Sa','So'].
  final List<String>? availableDays;
  final String? contactNote;

  bool get hasAvailability =>
      availableFrom != null ||
      availableUntil != null ||
      (availableDays != null && availableDays!.isNotEmpty);

  /// Liste der aktivierten Methoden in stabiler Reihenfolge.
  List<String> get enabledMethods {
    final out = <String>[];
    if (allowInAppChat) out.add('in_app_chat');
    if (allowPhone) out.add('phone');
    if (allowEmail) out.add('email');
    if (allowWhatsapp) out.add('whatsapp');
    if (allowLocationMeetup) out.add('location_meetup');
    return out;
  }

  factory PostContactPreference.fromJson(Map<String, dynamic> j) {
    final days = j['available_days'];
    return PostContactPreference(
      id: j['id'] as String?,
      postId: j['post_id'] as String,
      userId: j['user_id'] as String,
      allowInAppChat: j['allow_in_app_chat'] as bool? ?? true,
      allowPhone: j['allow_phone'] as bool? ?? false,
      allowEmail: j['allow_email'] as bool? ?? false,
      allowWhatsapp: j['allow_whatsapp'] as bool? ?? false,
      allowLocationMeetup: j['allow_location_meetup'] as bool? ?? false,
      phoneNumber: j['phone_number'] as String?,
      emailAddress: j['email_address'] as String?,
      whatsappNumber: j['whatsapp_number'] as String?,
      meetupNote: j['meetup_note'] as String?,
      availableFrom: j['available_from'] as String?,
      availableUntil: j['available_until'] as String?,
      availableDays: days is List ? days.map((e) => '$e').toList() : null,
      contactNote: j['contact_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'post_id': postId,
      'user_id': userId,
      'allow_in_app_chat': allowInAppChat,
      'allow_phone': allowPhone,
      'allow_email': allowEmail,
      'allow_whatsapp': allowWhatsapp,
      'allow_location_meetup': allowLocationMeetup,
    };
    if (id != null) m['id'] = id;
    if (phoneNumber != null && phoneNumber!.isNotEmpty) m['phone_number'] = phoneNumber;
    if (emailAddress != null && emailAddress!.isNotEmpty) m['email_address'] = emailAddress;
    if (whatsappNumber != null && whatsappNumber!.isNotEmpty) m['whatsapp_number'] = whatsappNumber;
    if (meetupNote != null && meetupNote!.isNotEmpty) m['meetup_note'] = meetupNote;
    if (availableFrom != null) m['available_from'] = availableFrom;
    if (availableUntil != null) m['available_until'] = availableUntil;
    if (availableDays != null && availableDays!.isNotEmpty) m['available_days'] = availableDays;
    if (contactNote != null && contactNote!.isNotEmpty) m['contact_note'] = contactNote;
    return m;
  }

  PostContactPreference copyWith({
    bool? allowInAppChat,
    bool? allowPhone,
    bool? allowEmail,
    bool? allowWhatsapp,
    bool? allowLocationMeetup,
    String? phoneNumber,
    String? emailAddress,
    String? whatsappNumber,
    String? meetupNote,
    String? availableFrom,
    String? availableUntil,
    List<String>? availableDays,
    String? contactNote,
  }) {
    return PostContactPreference(
      id: id,
      postId: postId,
      userId: userId,
      allowInAppChat: allowInAppChat ?? this.allowInAppChat,
      allowPhone: allowPhone ?? this.allowPhone,
      allowEmail: allowEmail ?? this.allowEmail,
      allowWhatsapp: allowWhatsapp ?? this.allowWhatsapp,
      allowLocationMeetup:
          allowLocationMeetup ?? this.allowLocationMeetup,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      meetupNote: meetupNote ?? this.meetupNote,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      availableDays: availableDays ?? this.availableDays,
      contactNote: contactNote ?? this.contactNote,
    );
  }
}
