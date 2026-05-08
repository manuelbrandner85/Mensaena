// Datenmodelle für DM-Calls (1:1 Audio/Video) – matched dm_calls 1:1.
// Migrationen: 20260428210000_dm_calls.sql + 20260429000000_dm_calls_whatsapp_pattern.sql.

import '../messages/models.dart';

enum DmCallStatus { ringing, active, ended, missed, declined, unknown }

enum DmCallType { audio, video }

class DmCall {
  const DmCall({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.roomName,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.endedReason,
    this.callerProfile,
  });

  final String id;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final DmCallType callType;
  final String roomName;
  final DmCallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? endedReason;
  final Profile? callerProfile;

  bool get isVideo => callType == DmCallType.video;

  DmCall copyWith({
    DmCallStatus? status,
    DateTime? answeredAt,
    DateTime? endedAt,
    String? endedReason,
    Profile? callerProfile,
  }) =>
      DmCall(
        id: id,
        conversationId: conversationId,
        callerId: callerId,
        calleeId: calleeId,
        callType: callType,
        roomName: roomName,
        status: status ?? this.status,
        createdAt: createdAt,
        answeredAt: answeredAt ?? this.answeredAt,
        endedAt: endedAt ?? this.endedAt,
        endedReason: endedReason ?? this.endedReason,
        callerProfile: callerProfile ?? this.callerProfile,
      );

  factory DmCall.fromJson(Map<String, dynamic> json) {
    Profile? caller;
    final p = json['profiles'] ?? json['caller'];
    if (p is Map<String, dynamic>) caller = Profile.fromJson(p);
    return DmCall(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      callType: _parseType(json['call_type'] as String?),
      roomName: (json['room_name'] as String?) ?? '',
      status: _parseStatus(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      endedReason: json['ended_reason'] as String?,
      callerProfile: caller,
    );
  }

  static DmCallStatus _parseStatus(String? s) {
    switch (s) {
      case 'ringing':
        return DmCallStatus.ringing;
      case 'active':
        return DmCallStatus.active;
      case 'ended':
        return DmCallStatus.ended;
      case 'missed':
        return DmCallStatus.missed;
      case 'declined':
        return DmCallStatus.declined;
      default:
        return DmCallStatus.unknown;
    }
  }

  static DmCallType _parseType(String? s) =>
      s == 'video' ? DmCallType.video : DmCallType.audio;
}
