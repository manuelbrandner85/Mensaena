/// SKILL: mensaena-features
/// NotificationRouter (F23): zentrale Map zwischen notification.type /
/// metadata und go_router-Pfad. Wird sowohl aus Notifications-Screen-Taps
/// als auch aus Firebase-Push-Tap-Handlern aufgerufen.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:go_router/go_router.dart';

import '../models/notification_model.dart';

class NotificationRouter {
  const NotificationRouter._();

  /// Aus dem In-App-Notifications-Screen.
  static void navigate(GoRouter router, AppNotification n) {
    final link = _resolveLink(n.type, n.category, _metaMap(n));
    if (link == null) {
      // Fallback: link-Feld aus DB
      if (n.link != null && n.link!.isNotEmpty) {
        router.go(n.link!);
      }
      return;
    }
    router.go(link);
  }

  /// Aus FCM-onMessageOpenedApp / getInitialMessage.
  static void navigateFromPush(GoRouter router, Map<String, dynamic> data) {
    final type = (data['type'] ?? data['category']) as String?;
    final link = _resolveLink(type, data['category'] as String?, data);
    if (link != null) {
      router.go(link);
    }
  }

  static Map<String, dynamic> _metaMap(AppNotification n) => n.metadata;

  static String? _resolveLink(
      String? type, String? category, Map<String, dynamic> meta) {
    final t = type ?? category;
    if (t == null) return null;

    // Chat / Messages
    if (t == 'chat_message' || t == 'message' || category == 'message') {
      final conv = meta['conversation_id']?.toString();
      if (conv != null) return '/dashboard/messages/$conv';
      return '/dashboard/messages';
    }

    // Mention — gleicher Pfad wie Chat (öffnet conversation, optional
    // mit highlight für message_id, das macht der Screen selbst).
    if (t == 'mention' || (meta['kind']?.toString() == 'mention')) {
      final conv = meta['conversation_id']?.toString();
      if (conv != null) return '/dashboard/messages/$conv';
      return '/dashboard/messages';
    }

    // Stream-Reminder — öffnet Liste geplanter Streams.
    if (meta['kind']?.toString() == 'stream_reminder') {
      return '/dashboard/live/scheduled';
    }

    // Scheduled-Call-Reminder — öffnet Liste geplanter Anrufe.
    if (meta['kind']?.toString() == 'scheduled_call_reminder') {
      return '/dashboard/scheduled-calls';
    }

    // Daily-Digest — Dashboard-Home.
    if (meta['kind']?.toString() == 'daily_digest') {
      return '/dashboard';
    }

    // Voicemail — öffnet Voicemail-Liste.
    if (t == 'voicemail' || meta['kind']?.toString() == 'voicemail') {
      return '/dashboard/voicemail';
    }

    // Contact-System
    if (t == 'contact_request_received') return '/contact-requests';
    if (t == 'contact_request_accepted' ||
        t == 'contact_request_declined') {
      final post = meta['post_id']?.toString();
      if (post != null) return '/dashboard/posts/$post';
      return '/dashboard/messages';
    }

    // Posts
    if (t == 'post_comment' || t == 'post_reaction' || t == 'post_share') {
      final post = meta['post_id']?.toString();
      if (post != null) return '/dashboard/posts/$post';
    }

    // Trust / Ratings
    if (t == 'trust_rating') {
      final viewerId = meta['rater_id']?.toString();
      return viewerId != null
          ? '/dashboard/profile/$viewerId'
          : '/dashboard/profile';
    }

    // Interactions
    if (t == 'interaction_update' ||
        t == 'interaction_offered' ||
        t == 'interaction_accepted') {
      return '/dashboard/interactions';
    }

    // Events
    if (t == 'event_reminder' || t == 'event_invite') {
      final eventId = meta['event_id']?.toString();
      if (eventId != null) return '/dashboard/events/$eventId';
      return '/dashboard/events';
    }

    // Livestream
    if (t == 'livestream_started' || t == 'livestream_scheduled') {
      final roomId = meta['room_id']?.toString();
      if (roomId != null) return '/dashboard/livestream/$roomId';
      return '/dashboard/livestreams';
    }

    // Calls
    if (t == 'call_missed' || t == 'incoming_call') {
      return '/dashboard/calls';
    }

    // Follow / Social
    if (t == 'follow_new') {
      final followerId = meta['follower_id']?.toString();
      if (followerId != null) return '/dashboard/profile/$followerId';
    }
    if (t == 'mentorship_assigned') {
      final convId = meta['conversation_id']?.toString();
      if (convId != null) return '/dashboard/messages/$convId';
    }

    // Gamification
    if (t == 'challenge_completed') return '/dashboard/challenges';
    if (t == 'badge_earned') return '/dashboard/badges';

    // Crisis
    if (t == 'crisis_alert') {
      final crisisId = meta['crisis_id']?.toString();
      if (crisisId != null) return '/dashboard/crisis/$crisisId';
      return '/dashboard/map';
    }

    debugPrint('[NotificationRouter] unmapped type=$t category=$category');
    return null;
  }
}
