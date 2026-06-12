import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
  /// [callType] muss 'audio' oder 'video' sein — DB-Spalte ist NOT NULL.
  static Future<DmCallStartResult> start({
    required String conversationId,
    required String calleeId,
    String callType = 'video',
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
    // JWT kann abgelaufen sein (Background, lange Idle) → refresh.
    await SupabaseService.ensureFreshSession();
    // Timestamp + 6-Zeichen-Random verhindert Kollision bei Spam-Tap
    // (1ms-Window war zu eng — zwei rapid Starts kollidierten).
    final rng = math.Random.secure();
    final suffix = List.generate(
        6, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[rng.nextInt(36)]).join();
    final roomName =
        'dm-${DateTime.now().millisecondsSinceEpoch}-$suffix';
    Future<Map<String, dynamic>?> doInsert() => sb
        .from('dm_calls')
        .insert({
          'caller_id': caller,
          'callee_id': calleeId,
          'conversation_id': conversationId,
          'call_type': callType,
          'status': 'ringing',
          'room_name': roomName,
        })
        .select('id, room_name')
        .maybeSingle();

    try {
      Map<String, dynamic>? row;
      try {
        row = await doInsert();
      } catch (e) {
        // 23505-Recovery: ein vorheriger Call derselben Konversation steckt
        // noch im Status ringing/active und kollidiert mit dem partiellen
        // Unique-Index. Wir setzen ihn auf 'ended' und versuchen es einmal
        // neu. Greift, falls die DB-seitige BEFORE-INSERT-Bereinigung noch
        // nicht deployed ist oder ein Edge-Case durchgerutscht ist.
        if (e.toString().contains('23505')) {
          try {
            await sb.from('dm_calls').update({
              'status': 'ended',
              'ended_at': DateTime.now().toUtc().toIso8601String(),
              'ended_reason': 'completed',
            }).match({
              'conversation_id': conversationId,
            }).inFilter('status', const ['ringing', 'active']);
            row = await doInsert();
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      if (row == null) {
        return const DmCallStartResult(
            success: false, errorReason: 'Insert blockiert (RLS)');
      }
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

  /// Punkt 13: Lädt eine weitere Person in einen LAUFENDEN Call ein.
  /// Erzeugt eine neue dm_calls-Row mit DEM SELBEN room_name → die Person
  /// klingelt (WhatsApp-Stil, via IncomingCallListener) und landet bei
  /// Annahme im selben LiveKit-Raum (Multi-Party). Liefert die neue callId.
  static Future<String?> invite({
    required String roomName,
    required String conversationId,
    required String calleeId,
    String callType = 'video',
  }) async {
    final caller = SupabaseService.currentUser?.id;
    if (caller == null || caller == calleeId) return null;
    await SupabaseService.ensureFreshSession();
    try {
      final row = await sb
          .from('dm_calls')
          .insert({
            'caller_id': caller,
            'callee_id': calleeId,
            'conversation_id': conversationId,
            'call_type': callType,
            'status': 'ringing',
            'room_name': roomName,
          })
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (e, st) {
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'dm_call_invite_failed',
        message: e.toString(),
        stack: st.toString(),
      );
      return null;
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

  /// Lehnt einen eingehenden Anruf ab weil der Callee bereits in einem
  /// anderen Call/Stream ist ("besetzt"). Der Anrufer sieht 'declined'.
  static Future<void> declineBusy(String callId) async {
    try {
      await sb.from('dm_calls').update({
        'status': 'declined',
        'ended_reason': 'declined',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (_) {}
  }

  /// Liefert die Kern-Metadaten eines Calls (oder null):
  /// caller_id, callee_id, status, conversation_id, call_type.
  static Future<Map<String, dynamic>?> fetchCall(String callId) async {
    try {
      return await sb
          .from('dm_calls')
          .select('caller_id, callee_id, status, conversation_id, call_type')
          .eq('id', callId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Realtime-Stream auf genau einen Call (Status-Übergänge ringing →
  /// active/cancelled/missed/ended). limit(1) Pflicht (Stream-Regeln).
  static Stream<List<Map<String, dynamic>>> watchCall(String callId) {
    return sb
        .from('dm_calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .limit(1);
  }

  /// Realtime-Stream der letzten 20 an [uid] gerichteten Calls — Quelle
  /// des IncomingCallListener (Dedupe/Popup-Logik bleibt im Widget).
  static Stream<List<Map<String, dynamic>>> watchIncomingFor(String uid) {
    return sb
        .from('dm_calls')
        .stream(primaryKey: ['id'])
        .eq('callee_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
  }

  /// Liefert die Konversations-ID zu einem Call (oder null).
  static Future<String?> conversationIdOf(String callId) async {
    try {
      final call = await sb
          .from('dm_calls')
          .select('conversation_id')
          .eq('id', callId)
          .maybeSingle();
      return call?['conversation_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Markiert den Call als aktiv (Peer-Connection steht).
  static Future<void> markActive(String callId) async {
    try {
      await sb
          .from('dm_calls')
          .update({'status': 'active'}).eq('id', callId);
    } catch (_) {}
  }

  /// Markiert den Call als verpasst (Ringing-Timeout).
  static Future<void> markMissed(String callId) async {
    try {
      await sb.from('dm_calls').update({
        'status': 'missed',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (_) {}
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

  /// Versteckt einen einzelnen Anruf im Verlauf des aktuellen Users
  /// (per-side soft-hide, kein Hard-Delete).
  static Future<bool> hideCallForMe(String callId) async {
    try {
      final r = await sb.rpc<dynamic>('hide_dm_call_for_me',
          params: {'p_call_id': callId});
      return r == true;
    } catch (e) {
      debugPrint('[hideCallForMe] failed: $e');
      return false;
    }
  }

  /// Räumt den kompletten Verlauf des aktuellen Users.
  static Future<int?> hideAllCallsForMe() async {
    try {
      final r = await sb.rpc<dynamic>('hide_all_dm_calls_for_me');
      if (r is int) return r;
      if (r is num) return r.toInt();
      return 0;
    } catch (e) {
      debugPrint('[hideAllCallsForMe] failed: $e');
      return null;
    }
  }
}

/// SKILL: mensaena-features
/// Pendant zu Web GlobalLiveRoom — jeder User kann in einem Channel
/// einen LiveKit-Stream starten. Alle anderen sehen einen Live-Banner
/// im Chat-Screen und koennen beitreten.
class LiveStreamService {
  const LiveStreamService._();

  /// Markiert einen Channel als Live. Returns room_name oder null bei Fehler;
  /// im Fehlerfall wird der echte Grund nach error_logs geschrieben.
  /// [conversationId] = chat_channels.conversation_id (FK).
  /// [channelSlug] fuer eindeutige room_name-Generierung.
  static Future<String?> startChannelStream({
    required String conversationId,
    required String channelSlug,
    String? topic,
  }) async {
    final host = SupabaseService.currentUser?.id;
    if (host == null) {
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'livestream_start_failed',
        message: 'no current user',
      );
      return null;
    }
    // JWT kann abgelaufen sein → refresh damit RLS-Insert nicht abgewiesen wird.
    await SupabaseService.ensureFreshSession();
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
    } catch (e, st) {
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'livestream_start_failed',
        message: e.toString(),
        stack: st.toString(),
        deviceInfo: 'conversation_id=$conversationId; channelSlug=$channelSlug',
      );
      return null;
    }
  }

  /// Gibt den room_name des aktuell laufenden Streams in einer Conversation,
  /// oder null wenn kein aktiver Stream existiert.
  static Future<String?> getActiveRoom(String conversationId) async {
    try {
      final row = await sb
          .from('live_rooms')
          .select('room_name')
          .eq('conversation_id', conversationId)
          .eq('status', 'live')
          .maybeSingle();
      return row?['room_name'] as String?;
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
        .limit(20)
        .map((rows) {
          final active = rows.where((r) => r['status'] == 'live').toList()
            ..sort((a, b) {
              final ta = DateTime.tryParse(
                      a['started_at'] as String? ?? '')?.toUtc() ??
                  DateTime(2000);
              final tb = DateTime.tryParse(
                      b['started_at'] as String? ?? '')?.toUtc() ??
                  DateTime(2000);
              return tb.compareTo(ta);
            });
          return active.isEmpty
              ? null
              : Map<String, dynamic>.from(active.first);
        });
  }

  /// Punkt 13: Lädt eine Person in einen laufenden Livestream ein. Sie
  /// bekommt eine Benachrichtigung (Tippen → landet direkt im Stream-Raum).
  /// Liefert true bei Erfolg.
  static Future<bool> inviteToStream({
    required String roomName,
    required String inviteeId,
    String? streamTitle,
  }) async {
    final host = SupabaseService.currentUser?.id;
    if (host == null || host == inviteeId) return false;
    await SupabaseService.ensureFreshSession();
    String hostName = 'Jemand';
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name')
          .eq('id', host)
          .maybeSingle();
      hostName = (p?['display_name'] as String?) ??
          (p?['name'] as String?) ??
          hostName;
    } catch (_) {}
    try {
      await sb.from('notifications').insert({
        'user_id': inviteeId,
        'actor_id': host,
        'type': 'livestream_invite',
        'category': 'system',
        'title': 'Livestream-Einladung',
        'body': '$hostName lädt dich in einen Livestream ein.',
        'link': '/dashboard/live/${Uri.encodeComponent(roomName)}?host=0',
        'metadata': {
          'room_name': roomName,
          if (streamTitle != null) 'title': streamTitle,
        },
      });
      return true;
    } catch (e, st) {
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'livestream_invite_failed',
        message: e.toString(),
        stack: st.toString(),
      );
      return false;
    }
  }
}
