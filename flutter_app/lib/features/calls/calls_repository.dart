import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase.dart';
import 'models.dart';

/// Repository für DM-Calls. Spiegelt 1:1 die Web-App-Endpoints
/// (`/api/dm-calls/{start,answer,end,decline,missed,cancel}`) und die
/// Realtime-Subscription auf der `dm_calls`-Tabelle.
class CallsRepository {
  CallsRepository(this._api);
  final ApiClient _api;

  /// Startet einen Call. Backend legt eine `dm_calls`-Zeile mit
  /// `status='ringing'` an und liefert callId + roomName zurück.
  Future<({String callId, String roomName})> start({
    required String conversationId,
    required DmCallType callType,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/start',
      body: {
        'conversationId': conversationId,
        'callType': callType == DmCallType.video ? 'video' : 'audio',
      },
    );
    final data = res.data!;
    return (
      callId: data['callId'] as String,
      roomName: data['roomName'] as String,
    );
  }

  /// Nimmt einen ankommenden Call an – setzt Status auf `active` und
  /// liefert das LiveKit-JWT + WebSocket-URL.
  Future<({String token, String wsUrl, String roomName})> answer(String callId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/answer',
      body: {'callId': callId},
    );
    final data = res.data!;
    return (
      token: data['token'] as String,
      wsUrl: data['url'] as String,
      roomName: (data['roomName'] as String?) ?? '',
    );
  }

  /// Holt nach erfolgreich gestartetem Outgoing-Call das JWT für den Caller
  /// (Pendant zum `/api/live-room/token`-Aufruf in OutgoingCallScreen.tsx,
  /// wenn der Callee auf `active` wechselt).
  Future<({String token, String wsUrl})> liveRoomToken({
    required String roomName,
    String? displayName,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/live-room/token',
      body: {
        'roomName': roomName,
        if (displayName != null) 'displayName': displayName,
      },
    );
    final data = res.data!;
    return (token: data['token'] as String, wsUrl: data['url'] as String);
  }

  Future<void> end(String callId) async {
    await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/end',
      body: {'callId': callId},
    );
  }

  Future<void> decline(String callId, {String reason = 'declined'}) async {
    await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/decline',
      body: {'callId': callId, 'reason': reason},
    );
  }

  Future<void> missed(String callId) async {
    await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/missed',
      body: {'callId': callId},
    );
  }

  Future<void> cancel(String callId) async {
    await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/cancel',
      body: {'callId': callId},
    );
  }

  /// Lädt einen einzelnen Call inkl. caller-Profil (für IncomingCallScreen).
  Future<DmCall?> fetchCall(String callId) async {
    final rows = await sb
        .from('dm_calls')
        .select(
          'id, conversation_id, caller_id, callee_id, call_type, room_name, '
          'status, created_at, answered_at, ended_at, ended_reason, '
          'profiles:caller_id(id, name, avatar_url)',
        )
        .eq('id', callId)
        .limit(1);
    if (rows.isEmpty) return null;
    return DmCall.fromJson(rows.first);
  }

  /// Realtime-Stream auf eingehende Calls für [calleeUserId]
  /// (status='ringing'). Filterung erfolgt clientseitig, da der serverseitige
  /// Filter zwischen supabase_flutter-Versionen drift hat.
  Stream<DmCall> incomingCalls(String calleeUserId) {
    final controller = StreamController<DmCall>.broadcast();
    final channel = sb.channel('dm_calls:incoming:$calleeUserId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'dm_calls',
      callback: (payload) async {
        final row = payload.newRecord;
        if (row['callee_id'] != calleeUserId) return;
        if (row['status'] != 'ringing') return;
        // 45s-Fenster respektieren (Web-App-Verhalten).
        final created = DateTime.tryParse(row['created_at'] as String? ?? '');
        if (created != null &&
            DateTime.now().toUtc().difference(created.toUtc()) >
                const Duration(seconds: 45)) {
          return;
        }
        final id = row['id'] as String?;
        if (id == null) return;
        final full = await fetchCall(id) ?? DmCall.fromJson(row);
        controller.add(full);
      },
    ).subscribe();
    controller.onCancel = () => sb.removeChannel(channel);
    return controller.stream;
  }

  /// Realtime-Stream auf Status-Updates EINES Calls (Outgoing wartet darauf,
  /// dass der Callee `active`/`declined` setzt).
  Stream<DmCall> callUpdates(String callId) {
    final controller = StreamController<DmCall>.broadcast();
    final channel = sb.channel('dm_calls:update:$callId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'dm_calls',
      callback: (payload) {
        final row = payload.newRecord;
        if (row['id'] != callId) return;
        controller.add(DmCall.fromJson(row));
      },
    ).subscribe();
    controller.onCancel = () => sb.removeChannel(channel);
    return controller.stream;
  }
}

final callsRepositoryProvider = Provider<CallsRepository>(
  (ref) => CallsRepository(ref.watch(apiClientProvider)),
);

/// Stream-Provider für eingehende Calls des aktuellen Users. Wird vom
/// `GlobalCallListener` konsumiert.
final incomingCallsProvider = StreamProvider<DmCall>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const Stream<DmCall>.empty();
  }
  final repo = ref.watch(callsRepositoryProvider);
  return repo.incomingCalls(user.id);
});
