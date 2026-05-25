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
import '../../../services/dm_call_service.dart';
import '../../../services/livekit_token_service.dart';
import '../../../services/room_events_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/shared/floating_reactions_layer.dart';
import '../../../widgets/shared/live_poll_overlay.dart';
import '../../../widgets/shared/live_subtitle_overlay.dart';
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
  String? _error;
  int _participantCount = 0;
  // Cache: identity → profile (name + avatar_url) für Avatar-Fallback.
  final Map<String, _ParticipantProfile> _profiles = {};
  // Room-Events Bus (Reactions/Polls/Highlights/Subtitles via DataChannel)
  RoomEventsService? _events;
  StreamSubscription<RoomEvent>? _eventsSub;
  // Floating-Hearts
  final FloatingReactionsController _reactionsCtrl =
      FloatingReactionsController();
  // Live-Poll-State (nur einer aktiv gleichzeitig)
  LivePoll? _activePoll;
  // Watcher-Panel sichtbar?
  bool _watchersOpen = false;
  // Subtitle-State
  SubtitleData? _currentSubtitle;
  Timer? _subtitleFadeTimer;
  // Watcher join/leave Toast-Queue
  String? _toastName;
  JoinLeaveKind? _toastKind;
  Timer? _toastTimer;
  // Highlights (host-collected)
  final List<DateTime> _highlights = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    // Mikro ist Default an → alle brauchen Mic-Permission beim Beitritt.
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
        _error = 'Mikrofon-Berechtigung verweigert.';
      });
      return;
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
    _listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) async {
        if (!mounted) return;
        setState(() => _state = _RoomState.ended);
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
      });

    try {
      await room.connect(tok.url, tok.token);
      // Mikro an, Kamera aus (User entscheidet via Toggle).
      await room.localParticipant?.setMicrophoneEnabled(_micEnabled);
      if (!mounted) return;
      // Prefetch profile data für alle Remote-Participants
      for (final p in room.remoteParticipants.values) {
        _fetchProfileFor(p.identity);
      }
      setState(() {
        _state = _RoomState.connected;
        _participantCount = room.remoteParticipants.length + 1;
      });
      // Events-Bus initialisieren (Reactions/Polls/Highlights/Subtitles).
      _events = RoomEventsService(room: room);
      _eventsSub = _events!.stream.listen(_onRoomEvent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
        _error = e.toString();
      });
    }
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

  Future<void> _leave() async {
    try {
      await _room?.disconnect();
    } catch (_) {}
    if (widget.isHost) {
      await LiveStreamService.endChannelStream(widget.roomName);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  @override
  void dispose() {
    if (widget.isHost) {
      LiveStreamService.endChannelStream(widget.roomName);
    }
    _eventsSub?.cancel();
    _events?.dispose();
    _reactionsCtrl.dispose();
    _subtitleFadeTimer?.cancel();
    _toastTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    try {
      _room?.disconnect();
    } catch (_) {}
    _room?.dispose();
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
        final id = ev.data['id'] as String?;
        final q = ev.data['question'] as String?;
        final opts = (ev.data['options'] as List?)?.cast<String>();
        if (id != null && q != null && opts != null && opts.isNotEmpty) {
          setState(() => _activePoll = LivePoll(
              id: id, question: q, options: opts));
        }
        break;
      case RoomEventType.pollVote:
        final pollId = ev.data['pollId'] as String?;
        final optionIndex = (ev.data['optionIndex'] as num?)?.toInt();
        if (pollId != null &&
            optionIndex != null &&
            _activePoll?.id == pollId) {
          setState(() {
            // Vorherigen Vote des Senders entfernen (re-vote moeglich)
            for (final s in _activePoll!.votes.values) {
              s.remove(ev.senderIdentity);
            }
            _activePoll!.votes
                .putIfAbsent(optionIndex, () => <String>{})
                .add(ev.senderIdentity);
          });
        }
        break;
      case RoomEventType.pollClose:
        setState(() => _activePoll = null);
        break;
      case RoomEventType.highlight:
        // Host hat einen Wichtig-Moment markiert — alle Zuschauer sehen
        // einen kurzen Toast.
        _showJoinLeaveToast('🔖 Highlight!', JoinLeaveKind.join);
        break;
      case RoomEventType.subtitle:
        final text = ev.data['text'] as String?;
        final lang = ev.data['lang'] as String? ?? 'de';
        if (text != null && text.isNotEmpty) {
          setState(() => _currentSubtitle = SubtitleData(
                text: text,
                sourceLang: lang,
                timestamp: DateTime.now(),
              ));
          _subtitleFadeTimer?.cancel();
          _subtitleFadeTimer = Timer(const Duration(seconds: 9), () {
            if (mounted) setState(() => _currentSubtitle = null);
          });
        }
        break;
      default:
        break;
    }
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

  Future<void> _hostStartPoll() async {
    final poll = await CreatePollSheet.show(context);
    if (poll == null || !mounted) return;
    setState(() => _activePoll = poll);
    await _events?.send(RoomEventType.pollStart, {
      'id': poll.id,
      'question': poll.question,
      'options': poll.options,
    });
  }

  Future<void> _vote(int optionIndex) async {
    final poll = _activePoll;
    if (poll == null) return;
    final me = _room?.localParticipant?.identity ?? '';
    if (me.isEmpty) return;
    setState(() {
      for (final s in poll.votes.values) {
        s.remove(me);
      }
      poll.votes.putIfAbsent(optionIndex, () => <String>{}).add(me);
    });
    await _events?.send(
        RoomEventType.pollVote, {'pollId': poll.id, 'optionIndex': optionIndex});
  }

  Future<void> _hostClosePoll() async {
    final poll = _activePoll;
    if (poll == null) return;
    setState(() => _activePoll = null);
    await _events?.send(RoomEventType.pollClose, {'pollId': poll.id});
  }

  Future<void> _markHighlight() async {
    _highlights.add(DateTime.now());
    _showJoinLeaveToast('🔖 Highlight gesetzt', JoinLeaveKind.join);
    await _events?.send(RoomEventType.highlight, {
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _sendSubtitle(String text) async {
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _currentSubtitle = SubtitleData(
        text: text, sourceLang: lang, timestamp: DateTime.now()));
    _subtitleFadeTimer?.cancel();
    _subtitleFadeTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _currentSubtitle = null);
    });
    await _events?.send(RoomEventType.subtitle, {
      'text': text,
      'lang': lang,
    });
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
    final targetLang = Localizations.localeOf(context).languageCode;
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
                    AppColors.bronze.withValues(alpha: 0.15),
                    AppColors.voidColor,
                  ],
                ),
              ),
            ),
            Column(
              children: [
                _ElegantHeader(
                  channelTitle: widget.channelTitle,
                  participantCount: _participantCount,
                  connected: _state == _RoomState.connected,
                  onClose: _leave,
                  onToggleWatchers: () =>
                      setState(() => _watchersOpen = !_watchersOpen),
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
                            ),
                ),
                // Live-Poll (falls aktiv) ueber dem ActionBar.
                if (_activePoll != null)
                  LivePollOverlay(
                    poll: _activePoll!,
                    onVote: _vote,
                    onClose: _hostClosePoll,
                    isHost: widget.isHost,
                    myIdentity:
                        _room?.localParticipant?.identity ?? '',
                  ),
                // Subtitle-Display unten ueber dem ActionBar.
                SubtitleDisplay(
                  subtitle: _currentSubtitle,
                  targetLang: targetLang,
                ),
                // Host-Subtitle-Composer (nur fuer Host).
                if (widget.isHost && _state == _RoomState.connected)
                  SubtitleComposer(onSend: _sendSubtitle),
                // Reaction-Picker fuer alle Teilnehmer.
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
                  onMicTap: _toggleMic,
                  onCamTap: _toggleCam,
                  onLeaveTap: _leave,
                  onStartPoll: widget.isHost && _activePoll == null
                      ? _hostStartPoll
                      : null,
                  onHighlight: widget.isHost ? _markHighlight : null,
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
  });

  final String channelTitle;
  final int participantCount;
  final bool connected;
  final VoidCallback onClose;
  final VoidCallback onToggleWatchers;

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
  });
  final lk.Room? room;
  final Map<String, _ParticipantProfile> profiles;
  final bool myMicEnabled;

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
            (p.name.isNotEmpty ? p.name : 'Teilnehmer:in');
        return _ParticipantTile(
          video: video,
          name: isLocal ? '$name (du)' : name,
          avatarUrl: profile?.avatarUrl,
          micMuted: micMuted,
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
  });

  final lk.VideoTrack? video;
  final String name;
  final String? avatarUrl;
  final bool micMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
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
    this.isHost = false,
    this.onStartPoll,
    this.onHighlight,
  });

  final bool micEnabled;
  final bool camEnabled;
  final bool enabled;
  final bool isHost;
  final VoidCallback onMicTap;
  final VoidCallback onCamTap;
  final VoidCallback onLeaveTap;
  final VoidCallback? onStartPoll;
  final VoidCallback? onHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.voidColor.withValues(alpha: 0),
            AppColors.voidColor,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundAction(
            icon: micEnabled ? LucideIcons.mic : LucideIcons.micOff,
            label: micEnabled ? 'Mikro an' : 'Stumm',
            color: micEnabled ? AppColors.leben : AppColors.mute,
            onTap: enabled ? onMicTap : null,
          ),
          _RoundAction(
            icon: camEnabled ? LucideIcons.video : LucideIcons.videoOff,
            label: camEnabled ? 'Kamera an' : 'Kamera aus',
            color: camEnabled ? AppColors.bronze : AppColors.mute,
            onTap: enabled ? onCamTap : null,
          ),
          if (isHost && onStartPoll != null)
            _RoundAction(
              icon: LucideIcons.barChart3,
              label: 'Umfrage',
              color: AppColors.bronze,
              onTap: onStartPoll,
            ),
          if (isHost && onHighlight != null)
            _RoundAction(
              icon: LucideIcons.bookmark,
              label: 'Highlight',
              color: AppColors.amber,
              onTap: onHighlight,
            ),
          _RoundAction(
            icon: LucideIcons.phoneOff,
            label: 'Verlassen',
            color: AppColors.herzrot,
            onTap: onLeaveTap,
            big: true,
          ),
        ],
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
