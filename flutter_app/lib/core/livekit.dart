import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

/// LiveKit-Service: kapselt den `Room`-Aufbau (Token-Auflösung erfolgt
/// in `features/calls/calls_repository.dart` über die `/api/dm-calls/answer`
/// bzw. `/api/live-room/token` Routes – identisch zur Web-App).
class LiveKitService {
  /// Öffnet einen LiveKit-Room mit dem angegebenen WebSocket-URL + JWT.
  /// `enableVideo` steuert, ob die Kamera initial publiziert wird.
  Future<Room> connect({
    required String wsUrl,
    required String token,
    bool enableVideo = false,
  }) async {
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    await room.connect(wsUrl, token);
    await room.localParticipant?.setMicrophoneEnabled(true);
    if (enableVideo) {
      await room.localParticipant?.setCameraEnabled(true);
    }
    return room;
  }
}

final liveKitServiceProvider = Provider<LiveKitService>((_) => LiveKitService());
