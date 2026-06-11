/// SKILL: mensaena-features + mensaena-design
/// Live-Room v2 — eleganter Player für Community-Livestreams.
///
/// Änderungen zu v1:
///   * ALLE Teilnehmer:innen dürfen publishen (Audio + Video), nicht nur Host.
///   * Mikro + Kamera-Toggle für jeden, Verlassen für jeden.
///   * Standard-Tracks beim Beitritt: Mic AN, Kamera AUS.
///   * Profil-Avatar (NetworkImage von profiles.avatar_url) als Fallback
///     wenn Kamera aus statt nur einer Initial.
///   * Header mit Bronze-Akzent, LIVE-Badge mit Pulse-Bloom,
///     Participant-Avatar-Stack rechts oben.
///   * Glass-Card-Tiles für jeden Teilnehmer mit Mic-Mute-Indikator.
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../providers/active_stream_provider.dart';
import '../../../services/call_busy_state.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/live_audio_service.dart';
import '../../../services/livekit_token_service.dart';
import '../../../services/stream_room_holder.dart';
import '../../../services/room_events_service.dart';
import '../../../services/supabase_service.dart';
import '../../../config/theme/cinema_theme.dart' show LightLeakSpot;
import '../../../widgets/effects/atmospheric_layers.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/effects/film_grain.dart';
import '../../../widgets/effects/light_leaks.dart';
import '../../../widgets/effects/vignette.dart';
import '../../../widgets/shared/floating_reactions_layer.dart';
import '../../../widgets/livestream/livestream_chat_resolver.dart';
import '../../../widgets/shared/user_picker_sheet.dart';
import '../../../widgets/shared/watcher_panel.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({
    required this.roomName,
    required this.channelTitle,
    required this.isHost,
    super.key,
  });

  final String roomName;
  final String channelTitle;
  final bool isHost;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

enum _RoomState { connecting, connected, ended, failed }

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  _RoomState _state = _RoomState.connecting;
  bool _micEnabled = true;
  bool _camEnabled = false;
  // true nur wenn der User den Stream WIRKLICH verlässt — steuert ob
  // dispose() den Room trennt oder im StreamRoomHolder weiterlaufen lässt.
  bool _left = false;
  // Schutz gegen parallele Reconnect-Versuche nach transientem Abbruch.
  bool _reconnecting = false;
  String? _error;
  int _participantCount = 0;
  // Cache: identity → profile (name + avatar_url) für Avatar-Fallback.
  final Map<String, _ParticipantProfile> _profiles = {};
  // Room-Events Bus (Reactions via DataChannel)
  RoomEventsService? _events;
  StreamSubscription<RoomEvent>? _eventsSub;
  // Floating-Hearts
  final FloatingReactionsController _reactionsCtrl =
      FloatingReactionsController();
  // Watcher-Panel sichtbar?
  bool _watchersOpen = false;
  // Watcher join/leave Toast-Queue
  String? _toastName;
  JoinLeaveKind? _toastKind;
  Timer? _toastTimer;
  // Hand-Heben: eigene Hand + Set ALLER Identities (inkl. self) mit erhobener
  // Hand. Wird via RoomEventType.handRaise über den DataChannel synchronisiert.
  bool _handRaised = false;
  final Set<String> _raisedHands = {};
  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    // Telegram-Modell: an einen noch laufenden Stream-Room reattachen
    // (User kam über den Mini-Player zurück). Kein Neu-Join.
    if (StreamRoomHolder.hasRoomFor(widget.roomName)) {
      await _reattach();
      return;
    }
    // Punkt 5: Mikro-Berechtigung anfragen, aber bei Ablehnung NICHT den
    // Beitritt blockieren — der User tritt dann als stummer Zuschauer bei
    // und kann das Mikro später per Toggle aktivieren (fragt erneut an).
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) {
      _micEnabled = false;
    }

    final myId = SupabaseService.currentUser?.id ?? 'guest';
    String myName = 'Mitglied';
    String? myAvatarUrl;
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name, avatar_url')
          .eq('id', myId)
          .maybeSingle();
      myName = (p?['display_name'] as String?) ??
          (p?['name'] as String?) ??
          'Mitglied';
      myAvatarUrl = p?['avatar_url'] as String?;
      _profiles[myId] =
          _ParticipantProfile(name: myName, avatarUrl: myAvatarUrl);
    } catch (_) {}

    final ({String token, String url}) tok;
    try {
      // V2: ALLE Teilnehmer dürfen publishen (Mic + Cam). Vorher: nur Host.
      tok = await LivekitTokenService.fetch(
        roomName: widget.roomName,
        displayName: myName,
        canPublish: true,
      );
    } on LivekitTokenError catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
        _error = 'Token-Fehler: ${e.message}';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
        _error = 'Token-Fehler: $e';
      });
      return;
    }

    final room = lk.Room();
    _room = room;
    // Punkt 4: User ist im Livestream → eingehende Anrufe als besetzt ablehnen.
    CallBusyState.inStream = true;
    // Punkt 11: Foreground-Service → Audio läuft im Hintergrund/Screen-off.
    LiveAudioService.start();
    _attachListeners(room);

    try {
      // B5: Timeout gegen ewigen Spinner, falls die SFU-Verbindung hängt
      // (Token ok, aber Server/Netz unerreichbar). 25 s → failed-State.
      await room.connect(tok.url, tok.token).timeout(
        const Duration(seconds: 25),
      );
      // Mikro an, Kamera aus (User entscheidet via Toggle).
      await room.localParticipant?.setMicrophoneEnabled(_micEnabled);
      if (!mounted) {
        // User hat den Screen während des Connects verlassen — der Room
        // wurde nie im Holder abgelegt, also hier komplett aufräumen,
        // sonst bleiben Besetzt-Status + Foreground-Service hängen.
        await _abortConnect(room);
        return;
      }
      // Prefetch profile data für alle Remote-Participants
      for (final p in room.remoteParticipants.values) {
        _fetchProfileFor(p.identity);
      }
      final startedAt = DateTime.now();
      setState(() {
        _state = _RoomState.connected;
        _participantCount = room.remoteParticipants.length + 1;
      });
      // Telegram-Modell: Room im Holder ablegen + Shell informieren, damit
      // er Screen-Disposal überlebt und der Mini-Player erscheint.
      StreamRoomHolder.store(
        r: room,
        roomName: widget.roomName,
        channelTitle: widget.channelTitle,
        isHost: widget.isHost,
        startedAt: startedAt,
      );
      ref.read(activeStreamProvider.notifier).state = ActiveStreamInfo(
        roomName: widget.roomName,
        channelTitle: widget.channelTitle,
        isHost: widget.isHost,
        startedAt: startedAt,
      );
      _attachEventsBus(room);
    } catch (e) {
      // Connect fehlgeschlagen (z. B. 25s-Timeout): Besetzt-Status,
      // Foreground-Service und Room IMMER zurücksetzen. Vorher blieb
      // CallBusyState.inStream=true hängen (alle eingehenden Anrufe
      // wurden dauerhaft als besetzt abgelehnt) und der Audio-Service
      // lief weiter (Akku), weil dispose() nur bei _left aufräumt.
      await _abortConnect(room);
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
        _error = e.toString();
      });
    }
  }

  /// Räumt einen fehlgeschlagenen/abgebrochenen Connect vollständig auf —
  /// Gegenstück zu dem, was VOR room.connect() aktiviert wurde.
  Future<void> _abortConnect(lk.Room room) async {
    CallBusyState.inStream = false;
    LiveAudioService.stop();
    _listener?.dispose();
    _listener = null;
    _room = null;
    try {
      await room.disconnect();
    } catch (_) {}
    try {
      await room.dispose();
    } catch (_) {}
  }

  /// Nach transientem Abbruch (Netzwerk-Blip beim Minimieren/Backgrounding):
  /// den toten Room sauber verwerfen und FRISCH neu beitreten — statt den
  /// User wie bisher hart aus dem Stream zu werfen. Holder + Foreground-
  /// Service bleiben durchgehend aktiv, der Mini-Player überlebt.
  Future<void> _attemptReconnect() async {
    if (_reconnecting || _left) return;
    _reconnecting = true;
    final dead = _room;
    _room = null;
    // Holder-Slot freigeben, damit der nachfolgende _connect() NICHT in den
    // Reattach-Pfad auf den toten Room läuft.
    StreamRoomHolder.room = null;
    StreamRoomHolder.roomName = null;
    try {
      await dead?.disconnect();
    } catch (_) {}
    try {
      await dead?.dispose();
    } catch (_) {}
    _eventsSub?.cancel();
    _eventsSub = null;
    _events?.dispose();
    _events = null;
    _listener?.dispose();
    _listener = null;
    if (mounted) setState(() => _state = _RoomState.connecting);
    await _connect();
    _reconnecting = false;
  }

  /// Telegram-Modell: Reattach an den im Holder laufenden Room (Rückkehr
  /// über Mini-Player) — kein erneuter LiveKit-Join, Audio lief durch.
  Future<void> _reattach() async {
    final room = StreamRoomHolder.room;
    if (room == null) {
      // Holder doch leer → normaler Connect-Pfad erneut.
      StreamRoomHolder.roomName = null;
      await _connect();
      return;
    }
    _room = room;
    CallBusyState.inStream = true;
    _attachListeners(room);
    _attachEventsBus(room);
    final myId = SupabaseService.currentUser?.id ?? 'guest';
    _micEnabled = room.localParticipant?.isMicrophoneEnabled() ?? _micEnabled;
    for (final p in room.remoteParticipants.values) {
      _fetchProfileFor(p.identity);
    }
    _fetchProfileFor(myId);
    if (!mounted) return;
    setState(() {
      _state = _RoomState.connected;
      _participantCount = room.remoteParticipants.length + 1;
    });
  }

  /// Hängt Room-Event-Listener an [room]. Von _connect UND _reattach genutzt
  /// (pro State neu gebaut, da die Closures auf diesen State zeigen).
  void _attachListeners(lk.Room room) {
    _listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((e) async {
        // Bug-Fix (User-Report): Zuschauer "flogen raus" beim Minimieren.
        // Ursache: JEDER Disconnect-Grund wurde als finales Stream-Ende
        // behandelt → Holder geleert + Foreground-Service gestoppt. Der Host
        // publisht durchgehend Audio und hält die Verbindung warm; ein reiner
        // Zuhörer trifft beim Backgrounding/Minimieren viel eher einen
        // TRANSIENTEN Abbruch — und wurde dadurch sofort komplett getrennt.
        //
        // Jetzt: nur bei TERMINALEN Gründen wirklich beenden. Transiente
        // Netzwerk-Abbrüche (disconnected, signalingConnectionFailure,
        // reconnectAttemptsExceeded, stateMismatch, unknown) → Reconnect-
        // Versuch, Holder + Audio-Service bleiben am Leben.
        const terminal = {
          lk.DisconnectReason.clientInitiated,
          lk.DisconnectReason.roomDeleted,
          lk.DisconnectReason.serverShutdown,
          lk.DisconnectReason.participantRemoved,
          lk.DisconnectReason.duplicateIdentity,
        };
        final reason = e.reason;
        final isTerminal = reason != null && terminal.contains(reason);
        if (!isTerminal && !_left) {
          await _attemptReconnect();
          return;
        }
        // Server-seitiges Ende → Stream wirklich vorbei: Holder + Shell
        // aufräumen, damit dispose() den Room final wegräumt.
        _left = true;
        StreamRoomHolder.room = null;
        StreamRoomHolder.roomName = null;
        CallBusyState.inStream = false;
        LiveAudioService.stop();
        if (mounted) {
          ref.read(activeStreamProvider.notifier).state = null;
          setState(() => _state = _RoomState.ended);
        }
      })
      ..on<lk.ParticipantConnectedEvent>((e) async {
        _fetchProfileFor(e.participant.identity);
        if (!mounted) return;
        setState(() =>
            _participantCount = (_room?.remoteParticipants.length ?? 0) + 1);
        _showJoinLeaveToast(
            e.participant.name.isNotEmpty
                ? e.participant.name
                : 'Nachbar:in',
            JoinLeaveKind.join);
      })
      ..on<lk.ParticipantDisconnectedEvent>((e) {
        if (!mounted) return;
        setState(() =>
            _participantCount = (_room?.remoteParticipants.length ?? 0) + 1);
        _showJoinLeaveToast(
            e.participant.name.isNotEmpty
                ? e.participant.name
                : 'Nachbar:in',
            JoinLeaveKind.leave);
        // Auto-Close: wenn der letzte Zuschauer den Livestream verlässt
        // (keine Remote-Teilnehmer mehr), beendet der Host den Stream
        // automatisch. Nur der Host darf live_rooms via RLS auf 'ended'
        // setzen — daher ist sein Client der korrekte Trigger-Punkt.
        _autoCloseIfEmpty();
      });
  }

  void _attachEventsBus(lk.Room room) {
    _events = RoomEventsService(room: room);
    _eventsSub = _events!.stream.listen(_onRoomEvent);
  }

  Future<void> _fetchProfileFor(String identity) async {
    if (_profiles.containsKey(identity)) return;
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name, avatar_url')
          .eq('id', identity)
          .maybeSingle();
      if (p == null) return;
      final name = (p['display_name'] as String?) ??
          (p['name'] as String?) ??
          'Mitglied';
      final avatarUrl = p['avatar_url'] as String?;
      _profiles[identity] =
          _ParticipantProfile(name: name, avatarUrl: avatarUrl);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_micEnabled;
    // Beim Aktivieren ggf. Mic-Berechtigung anfragen (Zuschauer der ohne
    // Mic beigetreten ist kann hier zum Sprecher werden).
    if (next) {
      final mic = await Permission.microphone.request();
      if (mic.isDenied || mic.isPermanentlyDenied) {
        _toast('Mikrofon-Berechtigung verweigert.');
        return;
      }
    }
    try {
      await lp.setMicrophoneEnabled(next);
      if (mounted) setState(() => _micEnabled = next);
    } catch (e) {
      _toast('Mikro-Fehler: $e');
    }
  }

  Future<void> _toggleCam() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_camEnabled;
    if (next) {
      final cam = await Permission.camera.request();
      if (cam.isDenied || cam.isPermanentlyDenied) {
        _toast('Kamera-Berechtigung verweigert.');
        return;
      }
    }
    try {
      await lp.setCameraEnabled(next);
      if (mounted) setState(() => _camEnabled = next);
    } catch (e) {
      _toast('Kamera-Fehler: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(msg,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  // Auto-Close-Guard: verhindert doppeltes Beenden, falls mehrere
  // Disconnect-Events kurz hintereinander feuern.
  bool _autoClosing = false;

  /// Beendet den Livestream automatisch, sobald der letzte Zuschauer ihn
  /// verlassen hat (keine Remote-Teilnehmer mehr). Nur der Host darf den
  /// Stream serverseitig auf 'ended' setzen (RLS) → daher löst nur dessen
  /// Client aus. Zuschauer-Clients tun nichts (Host-Leave beendet ohnehin).
  void _autoCloseIfEmpty() {
    if (_autoClosing || _left || !widget.isHost) return;
    final remote = _room?.remoteParticipants.length ?? 0;
    if (remote > 0) return;
    _autoClosing = true;
    _leave();
  }

  Future<void> _leave() async {
    // Echtes Verlassen → Room trennen + Holder/Shell aufräumen.
    _left = true;
    CallBusyState.inStream = false;
    LiveAudioService.stop();
    _room = null; // dispose() soll den Room nicht doppelt anfassen
    if (widget.isHost) {
      await LiveStreamService.endChannelStream(widget.roomName);
    }
    await StreamRoomHolder.clear();
    ref.read(activeStreamProvider.notifier).state = null;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  @override
  void dispose() {
    // Telegram-Modell: Bei reinem Minimieren/Wegnavigieren (nicht verlassen)
    // bleibt der Room im StreamRoomHolder aktiv → Audio läuft weiter, der
    // Mini-Player bringt zurück. Listener/Events gehören zu DIESEM State und
    // werden immer gelöst (Reattach baut sie neu). Der Room wird NUR bei
    // echtem Verlassen disposed.
    if (_left) {
      CallBusyState.inStream = false;
      LiveAudioService.stop();
    }
    _eventsSub?.cancel();
    _events?.dispose();
    _reactionsCtrl.dispose();
    _toastTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    if (_left) {
      try {
        _room?.disconnect();
      } catch (_) {}
      _room?.dispose();
    }
    _room = null;
    super.dispose();
  }

  // ─── Room-Events Handler ─────────────────────────────────────────
  void _onRoomEvent(RoomEvent ev) {
    switch (ev.type) {
      case RoomEventType.reaction:
        final emoji = ev.data['emoji'] as String?;
        if (emoji != null) _reactionsCtrl.spawn(emoji);
        break;
      case RoomEventType.pollStart:
      case RoomEventType.pollVote:
      case RoomEventType.pollClose:
        // User-Wunsch: Umfragen aus Livestream entfernt.
        break;
      case RoomEventType.highlight:
      case RoomEventType.subtitle:
        // User-Wunsch: Highlights + Untertitel aus Livestream entfernt.
        break;
      case RoomEventType.handRaise:
        final raised = ev.data['raised'] == true;
        if (!mounted) break;
        setState(() {
          if (raised) {
            _raisedHands.add(ev.senderIdentity);
          } else {
            _raisedHands.remove(ev.senderIdentity);
          }
        });
        if (raised) {
          final name = _profiles[ev.senderIdentity]?.name ??
              'live.participantFallback'.tr();
          _toast('live.handRaisedBy'.tr(namedArgs: {'name': name}));
        }
        break;
      case RoomEventType.moderate:
        // Kooperatives Moderations-Modell (gleiche Vertrauensbasis wie alle
        // anderen DataChannel-Events): Nur der Host blendet die Controls ein,
        // der Ziel-Client führt die Aktion an SICH selbst aus. Eine echte
        // serverseitige Durchsetzung (LiveKit RemoveParticipant) wäre ein
        // separater Edge-Function-Schritt.
        final target = ev.data['target'] as String?;
        final action = ev.data['action'] as String?;
        final myId = SupabaseService.currentUser?.id;
        if (target == null || myId == null || target != myId) break;
        if (action == 'mute') {
          _forceMuteSelf();
        } else if (action == 'remove') {
          _toast('live.removedByHost'.tr());
          _leave();
        }
        break;
      default:
        break;
    }
  }

  /// Eigene Hand heben/senken und an alle im Raum broadcasten.
  void _toggleHand() {
    final next = !_handRaised;
    final myId = SupabaseService.currentUser?.id ?? 'guest';
    setState(() {
      _handRaised = next;
      if (next) {
        _raisedHands.add(myId);
      } else {
        _raisedHands.remove(myId);
      }
    });
    _events?.send(RoomEventType.handRaise, {'raised': next});
  }

  /// Wird vom Host-Moderations-Event ausgelöst — schaltet das eigene Mikro aus.
  Future<void> _forceMuteSelf() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setMicrophoneEnabled(false);
      if (mounted) setState(() => _micEnabled = false);
      _toast('live.mutedByHost'.tr());
    } catch (_) {}
  }

  /// Host-Moderations-Sheet für einen Teilnehmer (stummschalten / entfernen).
  void _showModerationSheet(String identity, String name) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'live.moderateTitle'.tr(namedArgs: {'name': name}),
                style: AppTypography.body(
                    size: 14, color: AppColors.ink, weight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.micOff,
                  color: AppColors.amber, size: 20),
              title: Text('live.moderateMute'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.ink)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _events?.send(RoomEventType.moderate,
                    {'action': 'mute', 'target': identity});
                _toast('live.moderateMuteDone'.tr(namedArgs: {'name': name}));
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.userX,
                  color: AppColors.herzrot, size: 20),
              title: Text('live.moderateRemove'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.herzrotWarm)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _events?.send(RoomEventType.moderate,
                    {'action': 'remove', 'target': identity});
                _toast('live.moderateRemoveDone'.tr(namedArgs: {'name': name}));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showJoinLeaveToast(String name, JoinLeaveKind kind) {
    _toastTimer?.cancel();
    setState(() {
      _toastName = name;
      _toastKind = kind;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _toastName = null;
        _toastKind = null;
      });
    });
  }

  void _sendReaction(String emoji) {
    _reactionsCtrl.spawn(emoji);
    _events?.send(RoomEventType.reaction, {'emoji': emoji}, reliable: false);
  }


  /// Internen Livestream-Chat als DraggableScrollableSheet öffnen.
  /// LivestreamChatByRoomName resolved room_name → uuid intern.
  void _openChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, __) =>
            LivestreamChatByRoomName(roomName: widget.roomName),
      ),
    );
  }

  /// Punkt 13 (überarbeitet): Globales User-Picker-Sheet → JEDEN User
  /// einladen, nicht nur Freunde. Suche über display_name/name/nickname.
  Future<void> _inviteToStream() async {
    await UserPickerSheet.show(
      context,
      title: 'call.addParticipant'.tr(),
      pickedLabelKey: 'live.inviteSent',
      failedLabelKey: 'call.addFailed',
      onPick: (id, name) => LiveStreamService.inviteToStream(
        roomName: widget.roomName,
        inviteeId: id,
        streamTitle: widget.channelTitle,
      ),
    );
  }

  List<WatcherEntry> _buildWatcherList() {
    final out = <WatcherEntry>[];
    final r = _room;
    if (r == null) return out;
    final lp = r.localParticipant;
    if (lp != null) {
      out.add(WatcherEntry(
        identity: lp.identity,
        name: lp.name.isNotEmpty ? lp.name : 'Ich',
        avatarUrl: _profiles[lp.identity]?.avatarUrl,
      ));
    }
    for (final p in r.remoteParticipants.values) {
      out.add(WatcherEntry(
        identity: p.identity,
        name: p.name.isNotEmpty
            ? p.name
            : (_profiles[p.identity]?.name ?? p.identity),
        avatarUrl: _profiles[p.identity]?.avatarUrl,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Atmosphäre wächst mit der Anzahl der Live-Teilnehmer: leere Bühne
    // ist dezent, volle Bühne strahlt. Bezugspunkt ~8 Personen für volle
    // Sättigung — danach bleibt's konstant.
    final crowdGlow = (_participantCount.clamp(1, 8) / 8.0);
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Hintergrund-Gradient für cinematic Atmosphäre.
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    AppColors.bronze
                        .withValues(alpha: 0.10 + crowdGlow * 0.18),
                    AppColors.voidColor,
                  ],
                ),
              ),
            ),
            // Cinema-Atmosphäre — AtmosphericHaze + 2 LightLeaks + Grain + Vignette.
            const Positioned.fill(
              child: AtmosphericHaze(
                topColor: AppColors.bronze,
                bottomColor: AppColors.tealDeep,
                intensity: 0.35,
              ),
            ),
            Positioned.fill(
              child: LightLeaksOverlay(
                intensity: 0.30 + crowdGlow * 0.20,
                spots: const <LightLeakSpot>[
                  LightLeakSpot(
                    alignment: Alignment(-0.9, -0.85),
                    color: AppColors.bronze,
                    radius: 220,
                    opacity: 0.28,
                    pulse: true,
                  ),
                  LightLeakSpot(
                    alignment: Alignment(0.95, 0.7),
                    color: AppColors.herzrotWarm,
                    radius: 240,
                    opacity: 0.18,
                    pulse: true,
                  ),
                ],
              ),
            ),
            const Positioned.fill(child: VignetteOverlay(intensity: 0.42)),
            const Positioned.fill(child: FilmGrainOverlay(opacity: 0.025)),
            Column(
              children: [
                _ElegantHeader(
                  channelTitle: widget.channelTitle,
                  participantCount: _participantCount,
                  connected: _state == _RoomState.connected,
                  onClose: _leave,
                  onToggleWatchers: () =>
                      setState(() => _watchersOpen = !_watchersOpen),
                  onOpenChat: _openChatSheet,
                  onInvite: _inviteToStream,
                ),
                Expanded(
                  child: _state == _RoomState.connecting
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.bronze),
                        )
                      : _state == _RoomState.failed
                          ? _FailureView(error: _error)
                          : _RoomGrid(
                              room: _room,
                              profiles: _profiles,
                              myMicEnabled: _micEnabled,
                              raisedHands: _raisedHands,
                              isHost: widget.isHost,
                              onModerate: _showModerationSheet,
                            ),
                ),
                // User-Wunsch: Umfragen + Highlights + Untertitel raus.
                // Es bleibt nur der Reaction-Picker + Chat-Button im Header.
                if (_state == _RoomState.connected)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: ReactionPickerBar(onPick: _sendReaction),
                    ),
                  ),
                _ActionBar(
                  micEnabled: _micEnabled,
                  camEnabled: _camEnabled,
                  enabled: _state == _RoomState.connected,
                  isHost: widget.isHost,
                  handRaised: _handRaised,
                  onMicTap: _toggleMic,
                  onCamTap: _toggleCam,
                  onHandTap: _toggleHand,
                  onLeaveTap: _leave,
                ),
              ],
            ),
            // Floating-Reactions ueber dem ganzen Video-Bereich.
            Positioned.fill(
              child: IgnorePointer(
                child:
                    FloatingReactionsLayer(controller: _reactionsCtrl),
              ),
            ),
            // Join/Leave-Toasts oben mittig.
            if (_toastName != null && _toastKind != null)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: JoinLeaveToast(
                      name: _toastName!, kind: _toastKind!),
                ),
              ),
            // Side-Panel Watcher-Liste.
            if (_watchersOpen)
              WatcherPanel(
                watchers: _buildWatcherList(),
                onClose: () => setState(() => _watchersOpen = false),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Elegante Header-Komponente ──────────────────────────────────────
class _ElegantHeader extends StatelessWidget {
  const _ElegantHeader({
    required this.channelTitle,
    required this.participantCount,
    required this.connected,
    required this.onClose,
    required this.onToggleWatchers,
    required this.onOpenChat,
    required this.onInvite,
  });

  final String channelTitle;
  final int participantCount;
  final bool connected;
  final VoidCallback onClose;
  final VoidCallback onToggleWatchers;
  final VoidCallback onOpenChat;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.bronze.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // LIVE-Badge mit Pulse-Bloom
          PulseBloom(
            color: AppColors.herzrot,
            radius: 12,
            minIntensity: 0.4,
            maxIntensity: 0.9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.herzrot, AppColors.herzrotWarm],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE',
                      style: AppTypography.label(
                          size: 9,
                          color: Colors.white,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                if (connected)
                  Row(
                    children: [
                      const Icon(LucideIcons.users,
                          size: 10, color: AppColors.mute),
                      const SizedBox(width: 4),
                      Text(
                        participantCount == 1
                            ? 'Du allein'
                            : '$participantCount Teilnehmer:innen',
                        style: AppTypography.label(
                            size: 9, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            iconSize: 18,
            onPressed: onToggleWatchers,
            icon: const Icon(LucideIcons.users,
                color: AppColors.bronze),
            tooltip: 'watchers.show'.tr(),
          ),
          // Live-Stream-Chat — User-Wunsch: jeder kann reinschreiben.
          IconButton(
            iconSize: 18,
            onPressed: onOpenChat,
            icon: const Icon(LucideIcons.messageSquare,
                color: AppColors.bronze),
            tooltip: 'live.openChat'.tr(),
          ),
          // Punkt 13: Teilnehmer in den Livestream einladen.
          IconButton(
            iconSize: 18,
            onPressed: onInvite,
            icon: const Icon(LucideIcons.userPlus, color: AppColors.bronze),
            tooltip: 'call.addParticipant'.tr(),
          ),
          // Mini-Modus für Livestream: schließt Screen, MiniPlayer bleibt.
          IconButton(
            iconSize: 18,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(LucideIcons.minimize2,
                color: AppColors.bronze),
            tooltip: 'call.minimize'.tr(),
          ),
          IconButton(
            iconSize: 20,
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, color: AppColors.inkSoft),
            tooltip: 'live.tooltipLeave'.tr(),
          ),
        ],
      ),
    );
  }
}

// ─── Failure-View ────────────────────────────────────────────────────
class _FailureView extends StatelessWidget {
  const _FailureView({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.herzrot.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.herzrot.withValues(alpha: 0.4)),
              ),
              child: const Icon(LucideIcons.alertTriangle,
                  size: 28, color: AppColors.herzrotWarm),
            ),
            const SizedBox(height: 14),
            Text('live.connectionFailed'.tr(),
                style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Room-Grid ───────────────────────────────────────────────────────
class _RoomGrid extends StatefulWidget {
  const _RoomGrid({
    required this.room,
    required this.profiles,
    required this.myMicEnabled,
    required this.raisedHands,
    required this.isHost,
    required this.onModerate,
  });
  final lk.Room? room;
  final Map<String, _ParticipantProfile> profiles;
  final bool myMicEnabled;
  final Set<String> raisedHands;
  final bool isHost;
  final void Function(String identity, String name) onModerate;

  @override
  State<_RoomGrid> createState() => _RoomGridState();
}

class _RoomGridState extends State<_RoomGrid> {
  lk.EventsListener<lk.RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    if (r != null) {
      _listener = r.createListener()
        ..on<lk.TrackPublishedEvent>((_) => _rebuild())
        ..on<lk.TrackUnpublishedEvent>((_) => _rebuild())
        ..on<lk.TrackSubscribedEvent>((_) => _rebuild())
        ..on<lk.TrackUnsubscribedEvent>((_) => _rebuild())
        ..on<lk.TrackMutedEvent>((_) => _rebuild())
        ..on<lk.TrackUnmutedEvent>((_) => _rebuild())
        ..on<lk.LocalTrackPublishedEvent>((_) => _rebuild())
        ..on<lk.LocalTrackUnpublishedEvent>((_) => _rebuild());
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  lk.VideoTrack? _videoTrackFor(lk.Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.muted) continue;
      final t = pub.track;
      if (t is! lk.VideoTrack) continue;
      if (p is lk.RemoteParticipant && !pub.subscribed) continue;
      return t;
    }
    return null;
  }

  bool _isMicMuted(lk.Participant p) {
    for (final pub in p.audioTrackPublications) {
      if (!pub.muted) return false;
    }
    return p.audioTrackPublications.isEmpty
        ? false
        : true;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    if (r == null) return const SizedBox.shrink();
    final participants = <lk.Participant>[
      if (r.localParticipant != null) r.localParticipant!,
      ...r.remoteParticipants.values,
    ];
    if (participants.isEmpty) {
      return Center(
        child: Text('live.waitingParticipants'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 2 ? 1 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4 / 3,
      ),
      itemCount: participants.length,
      itemBuilder: (context, i) {
        final p = participants[i];
        final video = _videoTrackFor(p);
        final isLocal = p is lk.LocalParticipant;
        final micMuted =
            isLocal ? !widget.myMicEnabled : _isMicMuted(p);
        final profile = widget.profiles[p.identity];
        final name = profile?.name ??
            (p.name.isNotEmpty ? p.name : 'live.participantFallback'.tr());
        final handRaised = widget.raisedHands.contains(p.identity);
        // Host darf entfernte Teilnehmer per Tap moderieren (nicht sich selbst).
        final canModerate = widget.isHost && !isLocal;
        return _ParticipantTile(
          video: video,
          name: isLocal ? 'live.youSuffix'.tr(namedArgs: {'name': name}) : name,
          avatarUrl: profile?.avatarUrl,
          micMuted: micMuted,
          handRaised: handRaised,
          onTap: canModerate
              ? () => widget.onModerate(p.identity, name)
              : null,
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.video,
    required this.name,
    required this.avatarUrl,
    required this.micMuted,
    this.handRaised = false,
    this.onTap,
  });

  final lk.VideoTrack? video;
  final String name;
  final String? avatarUrl;
  final bool micMuted;
  final bool handRaised;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withValues(alpha: 0.55),
            AppColors.deep,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: AppColors.bronze.withValues(alpha: 0.25),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null)
            lk.VideoTrackRenderer(
              video!,
              fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _AvatarFallback(name: name, avatarUrl: avatarUrl),
          // Name + Mic-Status unten
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.voidColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 11,
                          color: AppColors.ink,
                          weight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    micMuted ? LucideIcons.micOff : LucideIcons.mic,
                    size: 11,
                    color: micMuted ? AppColors.herzrot : AppColors.leben,
                  ),
                ],
              ),
            ),
          ),
          // Video-aus-Indikator oben rechts wenn Kamera aus
          if (video == null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.voidColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(LucideIcons.videoOff,
                    size: 11, color: AppColors.mute),
              ),
            ),
          // Erhobene-Hand-Badge oben links.
          if (handRaised)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(LucideIcons.hand,
                    size: 12, color: AppColors.voidColor),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.30),
            AppColors.deep,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bronze.withValues(alpha: 0.20),
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: 0.6),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bronze.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initialPlaceholder(initial),
                errorWidget: (_, __, ___) => _initialPlaceholder(initial),
              )
            : _initialPlaceholder(initial),
      ),
    );
  }

  Widget _initialPlaceholder(String letter) => Container(
        color: AppColors.bronze.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Text(letter,
            style: AppTypography.display(size: 44, color: AppColors.bronze)),
      );
}

// ─── Action-Bar ─────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.micEnabled,
    required this.camEnabled,
    required this.enabled,
    required this.onMicTap,
    required this.onCamTap,
    required this.onLeaveTap,
    required this.handRaised,
    required this.onHandTap,
    this.isHost = false,
  });

  final bool micEnabled;
  final bool camEnabled;
  final bool enabled;
  final bool isHost;
  final bool handRaised;
  final VoidCallback onMicTap;
  final VoidCallback onCamTap;
  final VoidCallback onHandTap;
  final VoidCallback onLeaveTap;

  @override
  Widget build(BuildContext context) {
    // Frosted-Glass-Pille, gleiche Design-Sprache wie DM-Call.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0.85),
              AppColors.deep.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundAction(
              icon: micEnabled ? LucideIcons.mic : LucideIcons.micOff,
              label: micEnabled
                  ? 'liveAction.micOn'.tr()
                  : 'liveAction.muted'.tr(),
              color: micEnabled ? AppColors.leben : AppColors.mute,
              onTap: enabled ? onMicTap : null,
            ),
            _RoundAction(
              icon: LucideIcons.hand,
              label: handRaised
                  ? 'liveAction.lowerHand'.tr()
                  : 'liveAction.raiseHand'.tr(),
              color: handRaised ? AppColors.amber : AppColors.mute,
              onTap: enabled ? onHandTap : null,
            ),
            _RoundAction(
              icon: LucideIcons.phoneOff,
              label: 'liveAction.leave'.tr(),
              color: AppColors.herzrot,
              onTap: onLeaveTap,
              big: true,
            ),
            _RoundAction(
              icon: camEnabled ? LucideIcons.video : LucideIcons.videoOff,
              label: camEnabled
                  ? 'liveAction.camOn'.tr()
                  : 'liveAction.camOff'.tr(),
              color: camEnabled ? AppColors.bronze : AppColors.mute,
              onTap: enabled ? onCamTap : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 64.0 : 56.0;
    final iconSize = big ? 24.0 : 22.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.14),
                ],
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppTypography.label(size: 9, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _ParticipantProfile {
  const _ParticipantProfile({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;
}
