/// SKILL: mensaena-features
/// Globaler Halter für den aktiven DM-Call-LiveKit-Room.
///
/// Punkt 6 (User-Report 2026-05): Beim Wegnavigieren vom Call-Screen
/// (Minimieren → Mini-Player) wurde der LiveKit-Room im State.dispose()
/// getrennt → der Call/das Audio starb. Damit der Call im Hintergrund
/// weiterläuft, lebt der Room jetzt HIER (überlebt Screen-Disposal).
///
/// Lebenszyklus:
///   - CallScreen._connect() legt den Room hier ab.
///   - Beim Verlassen OHNE Auflegen bleibt der Room hier aktiv (Audio
///     läuft weiter, Mini-Player sichtbar).
///   - Tappt der User den Mini-Player, reattacht der neue CallScreen an
///     den hier gehaltenen Room statt neu zu verbinden (kein Doppel-Join).
///   - CallScreen._hangUp() / Peer-Unreachable / RoomDisconnected räumt
///     hier auf (clear()).
library;

import 'package:livekit_client/livekit_client.dart' as lk;

class CallRoomHolder {
  CallRoomHolder._();

  static lk.Room? room;
  static String? callId;
  static String? roomName;
  static String? peerName;
  static DateTime? startedAt;

  /// True wenn für [forCallId] bereits ein verbundener Room gehalten wird.
  static bool hasRoomFor(String forCallId) =>
      room != null && callId == forCallId;

  static void store({
    required lk.Room r,
    required String callId,
    required String roomName,
    required String peerName,
    required DateTime startedAt,
  }) {
    CallRoomHolder.room = r;
    CallRoomHolder.callId = callId;
    CallRoomHolder.roomName = roomName;
    CallRoomHolder.peerName = peerName;
    CallRoomHolder.startedAt = startedAt;
  }

  /// Trennt + verwirft den gehaltenen Room (echtes Auflegen).
  static Future<void> clear() async {
    final r = room;
    room = null;
    callId = null;
    roomName = null;
    peerName = null;
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
