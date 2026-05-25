/// SKILL: mensaena-features
/// ActiveCallProvider — globaler State eines laufenden DM-Anrufs.
///
/// Dient als Quelle fuer den "Anruf laeuft"-Banner im DashboardScaffold:
/// solange ein Call connected ist, weiss die Shell davon, auch wenn der
/// User aus dem Call-Screen wegnavigiert (z.B. zum Chat zum Tippen).
///
/// Setzen: CallScreen._connect() bei Erfolg.
/// Loeschen: CallScreen._hangUp() / _onPeerUnreachable() /
/// RoomDisconnectedEvent.
///
/// WICHTIG: Wenn der User per Back-Button navigiert OHNE aufzulegen,
/// bleibt der Provider gesetzt — der Call laeuft im Hintergrund weiter
/// und kann ueber den Banner wieder geoeffnet werden.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveCallInfo {
  const ActiveCallInfo({
    required this.callId,
    required this.roomName,
    required this.peerName,
    required this.startedAt,
    this.conversationId,
  });

  final String callId;
  final String roomName;
  final String peerName;
  final DateTime startedAt;
  final String? conversationId;
}

final activeCallProvider = StateProvider<ActiveCallInfo?>((ref) => null);
