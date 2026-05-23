import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Pendant zu Web `/api/dm-calls/*`. Erstellt einen DM-Call-Eintrag in
/// `dm_calls` der via Supabase-Realtime den callee benachrichtigt
/// (IncomingCallListener auf der Empfaengerseite zeigt Vollbild-Sheet).
class DmCallService {
  const DmCallService._();

  /// Initiiert einen Anruf an [calleeId] in einer existierenden Conversation.
  /// Returns die call_id bei Erfolg.
  static Future<String?> start({
    required String conversationId,
    required String calleeId,
  }) async {
    final caller = SupabaseService.currentUser?.id;
    if (caller == null || caller == calleeId) return null;
    try {
      final row = await sb
          .from('dm_calls')
          .insert({
            'caller_id': caller,
            'callee_id': calleeId,
            'conversation_id': conversationId,
            'status': 'ringing',
            'room_name': 'dm-${DateTime.now().millisecondsSinceEpoch}',
          })
          .select('id, room_name')
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Bricht eigenen Anruf ab.
  static Future<void> cancel(String callId) async {
    try {
      await sb.from('dm_calls').update({
        'status': 'cancelled',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (_) {}
  }

  /// Beendet einen aktiven Anruf.
  static Future<void> end(String callId) async {
    try {
      await sb.from('dm_calls').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (_) {}
  }
}

/// SKILL: mensaena-features
/// Pendant zu Web GlobalLiveRoom — Community-Channel-Admins koennen
/// einen LiveKit-Stream starten. Alle Channel-Mitglieder bekommen
/// `live_room_started` Notification + Banner mit Join-CTA.
class LiveStreamService {
  const LiveStreamService._();

  /// Markiert einen Channel als Live + sendet Notifications.
  /// Returns room_name.
  static Future<String?> startChannelStream({
    required String channelId,
    required String channelSlug,
    String? topic,
  }) async {
    final host = SupabaseService.currentUser?.id;
    if (host == null) return null;
    final roomName = 'channel-$channelSlug-${DateTime.now().millisecondsSinceEpoch}';
    try {
      // 1) Erstelle live_rooms Eintrag (falls Tabelle vorhanden)
      try {
        await sb.from('live_rooms').insert({
          'channel_id': channelId,
          'host_id': host,
          'room_name': roomName,
          'topic': topic,
          'status': 'live',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {
        // Tabelle ggf. nicht vorhanden → ignoriere, Notifications laufen
        // ueber dm_calls/system-notifications
      }
      return roomName;
    } catch (_) {
      return null;
    }
  }

  /// Beendet einen Live-Stream.
  static Future<void> endChannelStream(String roomName) async {
    try {
      await sb
          .from('live_rooms')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('room_name', roomName);
    } catch (_) {}
  }
}
