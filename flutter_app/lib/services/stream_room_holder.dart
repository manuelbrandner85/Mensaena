/// SKILL: mensaena-features
/// Globaler Halter für den aktiven Livestream-LiveKit-Room — Telegram-Modell.
///
/// User-Report: Beim Minimieren/Wegnavigieren ("PiP") wurde der Livestream
/// getrennt. Wie bei Telegram soll die Audio-Verbindung UNABHÄNGIG vom
/// Screen weiterlaufen, während der User sich frei in der App bewegt; ein
/// Mini-Player-Overlay bringt ihn zurück.
///
/// Der Room lebt daher hier (überlebt State.dispose). Verlässt der User den
/// Stream wirklich (Verlassen-Button), wird via clear() getrennt.
library;

import 'package:livekit_client/livekit_client.dart' as lk;

class StreamRoomHolder {
  StreamRoomHolder._();

  static lk.Room? room;
  static String? roomName;
  static String? channelTitle;
  static bool isHost = false;
  static DateTime? startedAt;

  static bool hasRoomFor(String forRoomName) =>
      room != null && roomName == forRoomName;

  static void store({
    required lk.Room r,
    required String roomName,
    required String channelTitle,
    required bool isHost,
    required DateTime startedAt,
  }) {
    StreamRoomHolder.room = r;
    StreamRoomHolder.roomName = roomName;
    StreamRoomHolder.channelTitle = channelTitle;
    StreamRoomHolder.isHost = isHost;
    StreamRoomHolder.startedAt = startedAt;
  }

  /// Trennt + verwirft den gehaltenen Room (echtes Verlassen).
  static Future<void> clear() async {
    final r = room;
    room = null;
    roomName = null;
    channelTitle = null;
    isHost = false;
    startedAt = null;
    if (r != null) {
      try {
        await r.disconnect();
      } catch (_) {}
      try {
        await r.dispose();
      } catch (_) {}
    }
  }
}
