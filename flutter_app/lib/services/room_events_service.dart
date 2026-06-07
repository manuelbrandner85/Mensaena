/// SKILL: mensaena-features
/// RoomEventsService — typisierte Data-Channel-Events fuer LiveKit-Rooms.
///
/// Eine duenne Schicht ueber `LocalParticipant.publishData()` + dem
/// `DataReceivedEvent`-Stream. Erlaubt Typed Events fuer:
///   - reaction: float-up Emoji (Call + Stream)
///   - poll_start / poll_vote / poll_close (Stream)
///   - highlight: Host markiert wichtige Sekunde (Stream)
///   - subtitle: Host tippt Untertitel, alle uebersetzen lokal (Beide)
///   - cheer: kurze Vibration + sound zur Begruessung (Beide)
///   - handRaise: Teilnehmer hebt/senkt die Hand (Beide). data: {'raised': bool}
///   - moderate: Host stummschaltet/entfernt einen Teilnehmer (Stream/Gruppe).
///               data: {'action': 'mute'|'remove', 'target': identity}
///
/// Verwendung:
///   final ev = RoomEventsService(room: room);
///   ev.send(RoomEventType.reaction, {'emoji': '❤️'});
///   ev.stream.listen((evt) => print(evt.type));
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:livekit_client/livekit_client.dart' as lk;

enum RoomEventType {
  reaction,
  pollStart,
  pollVote,
  pollClose,
  highlight,
  subtitle,
  cheer,
  handRaise,
  moderate,
  unknown,
}

class RoomEvent {
  const RoomEvent({
    required this.type,
    required this.data,
    required this.senderIdentity,
  });

  final RoomEventType type;
  final Map<String, dynamic> data;
  final String senderIdentity;
}

class RoomEventsService {
  RoomEventsService({required this.room}) {
    _listener = room.createListener()
      ..on<lk.DataReceivedEvent>(_onData);
  }

  final lk.Room room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final StreamController<RoomEvent> _ctrl =
      StreamController<RoomEvent>.broadcast();

  Stream<RoomEvent> get stream => _ctrl.stream;

  static const String topic = 'mensaena.room.events';

  Future<void> send(RoomEventType type, Map<String, dynamic> data,
      {bool reliable = true}) async {
    final lp = room.localParticipant;
    if (lp == null) return;
    try {
      final payload = json.encode({
        't': _typeKey(type),
        'd': data,
      });
      await lp.publishData(
        utf8.encode(payload),
        reliable: reliable,
        topic: topic,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[RoomEvents] send failed: $e');
    }
  }

  void _onData(lk.DataReceivedEvent ev) {
    if (ev.topic != topic) return;
    try {
      final raw = utf8.decode(ev.data);
      final j = json.decode(raw) as Map<String, dynamic>;
      final type = _parseType(j['t'] as String?);
      final data = (j['d'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      _ctrl.add(RoomEvent(
        type: type,
        data: data,
        senderIdentity: ev.participant?.identity ?? '',
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[RoomEvents] parse failed: $e');
    }
  }

  void dispose() {
    _listener?.dispose();
    _ctrl.close();
  }

  static String _typeKey(RoomEventType t) {
    switch (t) {
      case RoomEventType.reaction:
        return 'reaction';
      case RoomEventType.pollStart:
        return 'poll_start';
      case RoomEventType.pollVote:
        return 'poll_vote';
      case RoomEventType.pollClose:
        return 'poll_close';
      case RoomEventType.highlight:
        return 'highlight';
      case RoomEventType.subtitle:
        return 'subtitle';
      case RoomEventType.cheer:
        return 'cheer';
      case RoomEventType.handRaise:
        return 'hand_raise';
      case RoomEventType.moderate:
        return 'moderate';
      case RoomEventType.unknown:
        return 'unknown';
    }
  }

  static RoomEventType _parseType(String? key) {
    switch (key) {
      case 'reaction':
        return RoomEventType.reaction;
      case 'poll_start':
        return RoomEventType.pollStart;
      case 'poll_vote':
        return RoomEventType.pollVote;
      case 'poll_close':
        return RoomEventType.pollClose;
      case 'highlight':
        return RoomEventType.highlight;
      case 'subtitle':
        return RoomEventType.subtitle;
      case 'cheer':
        return RoomEventType.cheer;
      case 'hand_raise':
        return RoomEventType.handRaise;
      case 'moderate':
        return RoomEventType.moderate;
      default:
        return RoomEventType.unknown;
    }
  }
}
