import '../repositories/extra_repositories.dart';
import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Pendant zu Web `/api/dm-calls/*`. Erstellt einen DM-Call-Eintrag in
/// `dm_calls` der via Supabase-Realtime den callee benachrichtigt
/// (IncomingCallListener auf der Empfaengerseite zeigt Vollbild-Sheet).
class DmCallStartResult {
  const DmCallStartResult({
    required this.success,
    this.callId,
    this.roomName,
    this.errorReason,
  });

  final bool success;
  final String? callId;
  final String? roomName;
  final String? errorReason;
}

class DmCallService {
  const DmCallService._();

  /// Initiiert einen Anruf an [calleeId] in einer existierenden Conversation.
  /// Bei Erfolg: success=true mit callId+roomName.
  /// Bei Fehler: success=false mit errorReason (UI zeigt Snackbar).
  static Future<DmCallStartResult> start({
    required String conversationId,
    required String calleeId,
  }) async {
    final caller = SupabaseService.currentUser?.id;
    if (caller == null) {
      return const DmCallStartResult(
          success: false, errorReason: 'Nicht eingeloggt');
    }
    if (caller == calleeId) {
      return const DmCallStartResult(
          success: false, errorReason: 'Du kannst dich nicht selbst anrufen');
    }
    final roomName = 'dm-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final row = await sb
          .from('dm_calls')
          .insert({
            'caller_id': caller,
            'callee_id': calleeId,
            'conversation_id': conversationId,
            'status': 'ringing',
            'room_name': roomName,
          })
          .select('id, room_name')
          .single();
      final id = row['id'] as String?;
      if (id == null) {
        return const DmCallStartResult(
            success: false, errorReason: 'Keine Call-ID zurückgegeben');
      }
      return DmCallStartResult(
        success: true,
        callId: id,
        roomName: (row['room_name'] as String?) ?? roomName,
      );
    } catch (e, st) {
      // Log nach error_logs damit wir den echten Grund sehen.
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'dm_call_start_failed',
        message: e.toString(),
        stack: st.toString(),
      );
      return DmCallStartResult(
        success: false,
        errorReason: 'Anruf abgelehnt vom Server: ${e.toString()}',
      );
    }
  }

  /// Legacy: nur callId.
  static Future<String?> startCallId({
    required String conversationId,
    required String calleeId,
  }) async {
    final r = await start(conversationId: conversationId, calleeId: calleeId);
    return r.success ? r.callId : null;
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
/// Pendant zu Web GlobalLiveRoom — jeder User kann in einem Channel
/// einen LiveKit-Stream starten. Alle anderen sehen einen Live-Banner
/// im Chat-Screen und koennen beitreten.
class LiveStreamService {
  const LiveStreamService._();

  /// Markiert einen Channel als Live. Returns room_name.
  /// [conversationId] = chat_channels.conversation_id (FK).
  /// [channelSlug] fuer eindeutige room_name-Generierung.
  static Future<String?> startChannelStream({
    required String conversationId,
    required String channelSlug,
    String? topic,
  }) async {
    final host = SupabaseService.currentUser?.id;
    if (host == null) return null;
    final roomName =
        'channel-$channelSlug-${DateTime.now().millisecondsSinceEpoch}';
    try {
      // Lookup chat_channels.id von conversation_id (FK channel_id)
      String? channelId;
      try {
        final ch = await sb
            .from('chat_channels')
            .select('id')
            .eq('conversation_id', conversationId)
            .maybeSingle();
        channelId = ch?['id'] as String?;
      } catch (_) {}

      await sb.from('live_rooms').insert({
        if (channelId != null) 'channel_id': channelId,
        'conversation_id': conversationId,
        'host_id': host,
        'room_name': roomName,
        'topic': topic,
        'status': 'live',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
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

  /// Stream der aktiven live_rooms in einer Conversation (Channel).
  /// Liefert null wenn kein aktiver Live-Room → kein Banner anzeigen.
  static Stream<Map<String, dynamic>?> watchActiveRoom(
      String conversationId) {
    return sb
        .from('live_rooms')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((rows) {
          final active = rows.where((r) => r['status'] == 'live').toList()
            ..sort((a, b) {
              final ta = DateTime.tryParse(
                      a['started_at'] as String? ?? '') ??
                  DateTime(2000);
              final tb = DateTime.tryParse(
                      b['started_at'] as String? ?? '') ??
                  DateTime(2000);
              return tb.compareTo(ta);
            });
          return active.isEmpty
              ? null
              : Map<String, dynamic>.from(active.first);
        });
  }
}
