import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'api_client.dart';

/// LiveKit-Service: Voice-/Video-Calls (1:1-DMs + Live-Rooms).
/// Token-Generierung läuft über das bestehende Cloudflare-Backend
/// (/api/dm-calls/start, /api/live-room/token) – wie in der Web-App.
class LiveKitService {
  LiveKitService(this._api);
  final ApiClient _api;

  /// Holt einen LiveKit-Token für DM-Calls (Pendant zu /api/dm-calls/start).
  Future<({String token, String wsUrl, String roomName})> startDmCall({
    required String calleeUserId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/dm-calls/start',
      body: {'calleeId': calleeUserId},
    );
    final data = res.data!;
    return (
      token: data['token'] as String,
      wsUrl: data['wsUrl'] as String,
      roomName: data['roomName'] as String,
    );
  }

  /// Holt einen LiveKit-Token für einen Live-Room (Pendant zu /api/live-room/token).
  Future<({String token, String wsUrl})> getLiveRoomToken({
    required String roomName,
    String? identity,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/live-room/token',
      body: {'room': roomName, if (identity != null) 'identity': identity},
    );
    final data = res.data!;
    return (token: data['token'] as String, wsUrl: data['wsUrl'] as String);
  }

  /// Verbindet zu einem Room. Kommunikation über LiveKit-WebRTC.
  Future<Room> connect({required String wsUrl, required String token}) async {
    final room = Room();
    await room.connect(
      wsUrl,
      token,
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    return room;
  }
}

final liveKitServiceProvider = Provider<LiveKitService>(
  (ref) => LiveKitService(ref.watch(apiClientProvider)),
);
