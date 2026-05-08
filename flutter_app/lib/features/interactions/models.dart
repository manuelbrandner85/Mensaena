import 'package:flutter/material.dart';

enum InteractionStatus {
  requested,
  accepted,
  inProgress,
  completed,
  cancelledByHelper,
  cancelledByHelped,
  disputed,
  resolved,
  unknown;

  static InteractionStatus fromString(String? raw) {
    switch (raw) {
      case 'requested':
        return InteractionStatus.requested;
      case 'accepted':
        return InteractionStatus.accepted;
      case 'in_progress':
        return InteractionStatus.inProgress;
      case 'completed':
        return InteractionStatus.completed;
      case 'cancelled_by_helper':
        return InteractionStatus.cancelledByHelper;
      case 'cancelled_by_helped':
        return InteractionStatus.cancelledByHelped;
      case 'disputed':
        return InteractionStatus.disputed;
      case 'resolved':
        return InteractionStatus.resolved;
      default:
        return InteractionStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case InteractionStatus.requested:
        return 'Angefragt';
      case InteractionStatus.accepted:
        return 'Angenommen';
      case InteractionStatus.inProgress:
        return 'In Bearbeitung';
      case InteractionStatus.completed:
        return 'Abgeschlossen';
      case InteractionStatus.cancelledByHelper:
        return 'Helfer abgesagt';
      case InteractionStatus.cancelledByHelped:
        return 'Empfänger abgesagt';
      case InteractionStatus.disputed:
        return 'Streitfall';
      case InteractionStatus.resolved:
        return 'Geklärt';
      case InteractionStatus.unknown:
        return '–';
    }
  }

  Color get color {
    switch (this) {
      case InteractionStatus.requested:
        return const Color(0xFF1D4ED8);
      case InteractionStatus.accepted:
        return const Color(0xFF0F766E);
      case InteractionStatus.inProgress:
        return const Color(0xFFB45309);
      case InteractionStatus.completed:
        return const Color(0xFF15803D);
      case InteractionStatus.cancelledByHelper:
      case InteractionStatus.cancelledByHelped:
        return const Color(0xFFB91C1C);
      case InteractionStatus.disputed:
        return const Color(0xFFC2410C);
      case InteractionStatus.resolved:
        return const Color(0xFF374151);
      case InteractionStatus.unknown:
        return const Color(0xFF6B7280);
    }
  }
}

enum InteractionRole { helper, helped, unknown }

class InteractionPartner {
  const InteractionPartner({
    required this.id,
    this.name,
    this.avatarUrl,
    this.trustScore,
  });

  final String id;
  final String? name;
  final String? avatarUrl;
  final double? trustScore;

  String displayName() => name ?? 'Unbekannt';

  factory InteractionPartner.fromJson(Map<String, dynamic> j) =>
      InteractionPartner(
        id: j['id'] as String? ?? '',
        name: j['name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        trustScore: (j['trust_score'] as num?)?.toDouble(),
      );
}

class InteractionPostRef {
  const InteractionPostRef({required this.id, this.title, this.type});
  final String id;
  final String? title;
  final String? type;

  factory InteractionPostRef.fromJson(Map<String, dynamic> j) =>
      InteractionPostRef(
        id: j['id'] as String? ?? '',
        title: j['title'] as String?,
        type: j['type'] as String?,
      );
}

class Interaction {
  const Interaction({
    required this.id,
    required this.helperId,
    required this.status,
    required this.role,
    required this.partner,
    required this.createdAt,
    this.helpedId,
    this.message,
    this.responseMessage,
    this.conversationId,
    this.post,
  });

  final String id;
  final String helperId;
  final String? helpedId;
  final InteractionStatus status;
  final InteractionRole role;
  final InteractionPartner partner;
  final DateTime createdAt;
  final String? message;
  final String? responseMessage;
  final String? conversationId;
  final InteractionPostRef? post;

  bool get amIHelper => role == InteractionRole.helper;
  bool get isOpen =>
      status == InteractionStatus.requested ||
      status == InteractionStatus.accepted ||
      status == InteractionStatus.inProgress;

  factory Interaction.fromRpc(Map<String, dynamic> j, String currentUserId) {
    final helperId = j['helper_id'] as String? ?? '';
    final helpedId = j['helped_id'] as String?;
    final role = helperId == currentUserId
        ? InteractionRole.helper
        : helpedId == currentUserId
            ? InteractionRole.helped
            : InteractionRole.unknown;

    final partnerData = j['partner'] as Map<String, dynamic>?;
    final postData = j['post'] as Map<String, dynamic>?;

    return Interaction(
      id: j['id'] as String,
      helperId: helperId,
      helpedId: helpedId,
      status: InteractionStatus.fromString(j['status'] as String?),
      role: role,
      partner: partnerData != null
          ? InteractionPartner.fromJson(partnerData)
          : InteractionPartner(id: helperId == currentUserId ? (helpedId ?? '') : helperId),
      createdAt: DateTime.parse(j['created_at'] as String),
      message: j['message'] as String?,
      responseMessage: j['response_message'] as String?,
      conversationId: j['conversation_id'] as String?,
      post: postData != null ? InteractionPostRef.fromJson(postData) : null,
    );
  }
}
