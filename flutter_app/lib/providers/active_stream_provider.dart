/// SKILL: mensaena-features
/// Globaler State eines laufenden Livestreams (Telegram-Modell).
///
/// Solange gesetzt, weiß die App-Shell vom laufenden Stream und zeigt den
/// ActiveStreamMiniPlayer — der User bewegt sich frei in der App, hört aber
/// weiter mit (Room lebt im StreamRoomHolder).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveStreamInfo {
  const ActiveStreamInfo({
    required this.roomName,
    required this.channelTitle,
    required this.isHost,
    required this.startedAt,
  });

  final String roomName;
  final String channelTitle;
  final bool isHost;
  final DateTime startedAt;
}

final activeStreamProvider = StateProvider<ActiveStreamInfo?>((ref) => null);
