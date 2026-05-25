import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
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
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/bloom.dart';

/// SKILL: mensaena-features
/// 1:1-DM-Anruf (Audio + optional Video) via LiveKit.
/// Erwartet einen bereits in dm_calls erstellten Call (callId + roomName).
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    required this.callId,
    required this.roomName,
    required this.peerName,
    super.key,
  });

  final String callId;
  final String roomName;
  final String peerName;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

enum _CallState {
  outgoingRinging,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

class _CallScreenState extends ConsumerState<CallScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  _CallState _state = _CallState.connecting;
  bool _micEnabled = true;
  bool _camEnabled = false;
  bool _speakerOn = false;
  String? _error;
  String? _peerAvatarUrl;
  bool _isCaller = false;
  AudioPlayer? _ringback;
  Timer? _ringbackHaptic;
  Timer? _ringingTimeout;
  StreamSubscription<List<Map<String, dynamic>>>? _callStatusSub;
  // Call-Duration-Timer — startet bei connected.
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  // Mini-Cam-Preview-Position (draggable).
  Offset _camPreviewPos = const Offset(16, 100);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadPeerAvatar();
  }

  /// Entscheidet ob wir Caller (Outgoing-Ringing-UI + Ringback) oder
  /// Callee (sofort LiveKit-Connect — Annahme erfolgt schon vor Nav) sind.
  Future<void> _bootstrap() async {
    try {
      final me = SupabaseService.currentUser?.id;
      final call = await sb
          .from('dm_calls')
          .select('caller_id, callee_id, status')
          .eq('id', widget.callId)
          .maybeSingle();
      if (call == null) {
        await _connect();
        return;
      }
      final callerId = call['caller_id'] as String?;
      final status = call['status'] as String?;
      _isCaller = me != null && callerId == me;
      // Caller + Status noch 'ringing' → Outgoing-Ringing-Modus.
      if (_isCaller && status == 'ringing') {
        if (mounted) {
          setState(() => _state = _CallState.outgoingRinging);
        }
        _startRingback();
        _watchCallStatus();
        // 45s Timeout (parallel zur Callee-Seite).
        _ringingTimeout = Timer(const Duration(seconds: 45), () {
          if (_state == _CallState.outgoingRinging) {
            _onPeerUnreachable(status: 'missed');
          }
        });
        return;
      }
      // Sonst: direkt connecten (Callee-Side oder bereits 'active').
      await _connect();
    } catch (_) {
      await _connect();
    }
  }

  void _watchCallStatus() {
    try {
      _callStatusSub = sb
          .from('dm_calls')
          .stream(primaryKey: ['id'])
          .eq('id', widget.callId)
          .listen((rows) async {
            if (rows.isEmpty) return;
            final r = rows.first;
            final s = r['status'] as String?;
            if (s == 'active') {
              _ringingTimeout?.cancel();
              await _stopRingback();
              if (!mounted) return;
              setState(() => _state = _CallState.connecting);
              await _connect();
            } else if (s == 'cancelled' || s == 'missed' || s == 'ended') {
              _onPeerUnreachable(status: s ?? 'cancelled');
            }
          });
    } catch (_) {}
  }

  Future<void> _startRingback() async {
    // Versuche zuerst die Asset-MP3. Wenn nicht vorhanden — Vibrations-Pulse
    // als Fallback (haptic alle 2s).
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.6);
      await player.play(AssetSource('sounds/ringback.mp3'));
      _ringback = player;
    } catch (_) {
      _ringback = null;
    }
    // Haptic-Pulse parallel: dezenter Tap alle 2 Sekunden bis Verbindung.
    _ringbackHaptic = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.lightImpact();
    });
  }

  Future<void> _stopRingback() async {
    _ringbackHaptic?.cancel();
    _ringbackHaptic = null;
    try {
      await _ringback?.stop();
      await _ringback?.dispose();
    } catch (_) {}
    _ringback = null;
  }

  Future<void> _onPeerUnreachable({String status = 'missed'}) async {
    _ringingTimeout?.cancel();
    await _stopRingback();
    if (status == 'missed') {
      try {
        await sb.from('dm_calls').update({
          'status': 'missed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.callId);
      } catch (_) {}
    }
    if (!mounted) return;
    final msg = status == 'cancelled'
        ? 'call.callDeclined'.tr()
        : 'call.notReachable'.tr();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(msg,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  Future<void> _cancelOutgoing() async {
    _ringingTimeout?.cancel();
    await _stopRingback();
    await DmCallService.cancel(widget.callId);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  Future<void> _loadPeerAvatar() async {
    // Versuch: ermittle Peer-ID via dm_calls + lade Profil-Bild.
    try {
      final me = SupabaseService.currentUser?.id;
      if (me == null) return;
      final call = await sb
          .from('dm_calls')
          .select('caller_id, callee_id')
          .eq('id', widget.callId)
          .maybeSingle();
      if (call == null) return;
      final peerId = call['caller_id'] == me
          ? call['callee_id'] as String?
          : call['caller_id'] as String?;
      if (peerId == null) return;
      final p = await sb
          .from('profiles')
          .select('avatar_url')
          .eq('id', peerId)
          .maybeSingle();
      if (mounted) {
        setState(() => _peerAvatarUrl = p?['avatar_url'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    // Permissions
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Mikrofon-Berechtigung verweigert.';
      });
      return;
    }

    // Display Name fuer LiveKit-Identity (best-effort)
    final myId = SupabaseService.currentUser?.id ?? 'guest';
    String myName = 'Mitglied';
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name')
          .eq('id', myId)
          .maybeSingle();
      myName = (p?['display_name'] as String?) ??
          (p?['name'] as String?) ??
          'Mitglied';
    } catch (_) {}

    // Token holen
    final ({String token, String url}) tok;
    try {
      tok = await LivekitTokenService.fetch(
        roomName: widget.roomName,
        displayName: myName,
        canPublish: true,
      );
    } on LivekitTokenError catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Token-Fehler: ${e.message}';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Token-Fehler: $e';
      });
      return;
    }

    final room = lk.Room();
    _room = room;
    _listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) async {
        if (!mounted) return;
        // Wenn waehrend Reconnecting der Server endgueltig aufgibt,
        // kommt RoomDisconnectedEvent. Sonst war's ein sauberer Hangup.
        setState(() => _state = _CallState.ended);
        _stopwatch.stop();
        _ticker?.cancel();
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        if (!mounted) return;
        setState(() => _state = _CallState.reconnecting);
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        if (!mounted) return;
        setState(() => _state = _CallState.connected);
      });

    try {
      await room.connect(tok.url, tok.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() => _state = _CallState.connected);
      // Call-Duration-Timer starten.
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      // Critical: tell CallKit/Telecom the call connected. Without this,
      // iOS auto-ends after 30s "no answer" and Android's ConnectionService
      // stays in a half-ringing state.
      try {
        await FlutterCallkitIncoming.setCallConnected(widget.callId);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_micEnabled;
    await lp.setMicrophoneEnabled(next);
    setState(() => _micEnabled = next);
  }

  Future<void> _toggleCam() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    if (!_camEnabled) {
      final cam = await Permission.camera.request();
      if (cam.isDenied || cam.isPermanentlyDenied) return;
    }
    final next = !_camEnabled;
    await lp.setCameraEnabled(next);
    setState(() => _camEnabled = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(next);
      setState(() => _speakerOn = next);
    } catch (_) {/* Hardware-Plattform-Bridge fehlt evtl. */}
  }

  Future<void> _hangUp() async {
    try {
      await _room?.disconnect();
    } catch (_) {}
    await DmCallService.end(widget.callId);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  @override
  void dispose() {
    _ringingTimeout?.cancel();
    _ringbackHaptic?.cancel();
    _callStatusSub?.cancel();
    _ticker?.cancel();
    _stopwatch.stop();
    try {
      _ringback?.stop();
      _ringback?.dispose();
    } catch (_) {}
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Outgoing-Ringing-Sonder-UI: Avatar mit Pulse-Ring + Cancel-Button.
    if (_state == _CallState.outgoingRinging) {
      return _OutgoingRingingView(
        peerName: widget.peerName,
        avatarUrl: _peerAvatarUrl,
        onCancel: _cancelOutgoing,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        children: [
          SafeArea(child: _buildBody()),
          if (_camEnabled && _room != null)
            Positioned(
              left: _camPreviewPos.dx,
              top: _camPreviewPos.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _camPreviewPos += d.delta;
                  });
                },
                child: _LocalCamPreview(room: _room!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
          children: [
            const SizedBox(height: 24),
            Text(
              widget.peerName,
              style: AppTypography.display(
                  size: 26, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(_subtitle(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
            const Spacer(),
            // Wenn Remote-Video vorhanden: zeige Video. Sonst: großer Avatar.
            _PeerVideoOrAvatar(
              room: _room,
              peerName: widget.peerName,
              avatarUrl: _peerAvatarUrl,
            ),
            if (_state == _CallState.failed && _error != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                      size: 12, color: AppColors.herzrotWarm),
                ),
              ),
            ],
            const Spacer(),
            // Action Bar — 4 Buttons: Mic, Speaker, Hangup, Cam.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleAction(
                    icon: _micEnabled
                        ? LucideIcons.mic
                        : LucideIcons.micOff,
                    label: _micEnabled ? 'Mute' : 'Unmute',
                    color: _micEnabled
                        ? AppColors.bronze
                        : AppColors.herzrotWarm,
                    onTap: _state == _CallState.connected ? _toggleMic : null,
                  ),
                  _CircleAction(
                    icon: _speakerOn
                        ? LucideIcons.volume2
                        : LucideIcons.volumeX,
                    label: _speakerOn ? 'Lautspr.' : 'Hörer',
                    color: _speakerOn ? AppColors.bronze : AppColors.mute,
                    onTap:
                        _state == _CallState.connected ? _toggleSpeaker : null,
                  ),
                  _CircleAction(
                    icon: LucideIcons.phoneOff,
                    label: 'Auflegen',
                    color: AppColors.herzrot,
                    big: true,
                    onTap: _hangUp,
                  ),
                  _CircleAction(
                    icon: _camEnabled
                        ? LucideIcons.video
                        : LucideIcons.videoOff,
                    label: _camEnabled ? 'Cam aus' : 'Cam an',
                    color: _camEnabled
                        ? AppColors.bronze
                        : AppColors.mute,
                    onTap: _state == _CallState.connected ? _toggleCam : null,
                  ),
                ],
              ),
            ),
          ],
        );
  }

  String _subtitle() {
    switch (_state) {
      case _CallState.outgoingRinging:
        return 'call.calling'.tr();
      case _CallState.connecting:
        return 'Verbinde…';
      case _CallState.connected:
        return _formatDuration(_stopwatch.elapsed);
      case _CallState.reconnecting:
        return 'Verbindung wird wiederhergestellt…';
      case _CallState.ended:
        return 'call.callEnded'.tr();
      case _CallState.failed:
        return 'Verbindung fehlgeschlagen';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────
// OutgoingRingingView — WhatsApp-Style "Klingelt…" beim Anrufen
// ─────────────────────────────────────────────────────────────
class _OutgoingRingingView extends StatefulWidget {
  const _OutgoingRingingView({
    required this.peerName,
    required this.onCancel,
    this.avatarUrl,
  });

  final String peerName;
  final String? avatarUrl;
  final VoidCallback onCancel;

  @override
  State<_OutgoingRingingView> createState() => _OutgoingRingingViewState();
}

class _OutgoingRingingViewState extends State<_OutgoingRingingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.peerName.isNotEmpty
        ? widget.peerName[0].toUpperCase()
        : '?';
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final scale = 1.0 + _pulse.value * 0.18;
                final opacity = 0.55 - _pulse.value * 0.35;
                return SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.bronze
                                  .withValues(alpha: opacity),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 160,
                        height: 160,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bronze.withValues(alpha: 0.18),
                          border:
                              Border.all(color: AppColors.bronze, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.avatarUrl != null &&
                                widget.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Text(
                                  initial,
                                  style: AppTypography.display(
                                      size: 56, color: AppColors.bronze),
                                ),
                                errorWidget: (_, __, ___) => Text(
                                  initial,
                                  style: AppTypography.display(
                                      size: 56, color: AppColors.bronze),
                                ),
                              )
                            : Text(
                                initial,
                                style: AppTypography.display(
                                    size: 56, color: AppColors.bronze),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              widget.peerName,
              style: AppTypography.display(
                  size: 28, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'call.calling'.tr(),
              style: AppTypography.body(size: 14, color: AppColors.inkSoft),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onCancel,
                    borderRadius: BorderRadius.circular(72),
                    child: Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.herzrot.withValues(alpha: 0.22),
                        border:
                            Border.all(color: AppColors.herzrot, width: 2),
                      ),
                      child: const Icon(LucideIcons.phoneOff,
                          color: AppColors.herzrot, size: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'call.cancelCall'.tr(),
                    style: AppTypography.label(
                        size: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
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
    final size = big ? 72.0 : 60.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
            child: Icon(icon, color: color, size: big ? 28 : 22),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppTypography.label(size: 10, color: AppColors.inkSoft)),
      ],
    );
  }
}

// ── PeerVideoOrAvatar — zeigt Remote-Video oder großen Avatar ──────
class _PeerVideoOrAvatar extends StatefulWidget {
  const _PeerVideoOrAvatar({
    required this.room,
    required this.peerName,
    required this.avatarUrl,
  });

  final lk.Room? room;
  final String peerName;
  final String? avatarUrl;

  @override
  State<_PeerVideoOrAvatar> createState() => _PeerVideoOrAvatarState();
}

class _PeerVideoOrAvatarState extends State<_PeerVideoOrAvatar> {
  lk.EventsListener<lk.RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    if (r != null) {
      _listener = r.createListener()
        ..on<lk.TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  lk.VideoTrack? _findPeerVideo() {
    final r = widget.room;
    if (r == null) return null;
    for (final p in r.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (pub.muted || !pub.subscribed) continue;
        final t = pub.track;
        if (t is lk.VideoTrack) return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _findPeerVideo();
    if (video != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 240,
          height: 320,
          child: lk.VideoTrackRenderer(
            video,
            fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }
    final initial = widget.peerName.isNotEmpty
        ? widget.peerName[0].toUpperCase()
        : '?';
    return PulseBloom(
      color: AppColors.bronze,
      radius: 38,
      minIntensity: 0.4,
      maxIntensity: 0.8,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bronze.withValues(alpha: 0.22),
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: 0.55),
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initial(initial),
                errorWidget: (_, __, ___) => _initial(initial),
              )
            : _initial(initial),
      ),
    );
  }

  Widget _initial(String letter) => Container(
        color: AppColors.bronze.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: Text(letter,
            style:
                AppTypography.display(size: 72, color: AppColors.bronze)),
      );
}

// ── LocalCamPreview — eigenes Kamerabild als kleines draggable Tile ──
class _LocalCamPreview extends StatefulWidget {
  const _LocalCamPreview({required this.room});
  final lk.Room room;

  @override
  State<_LocalCamPreview> createState() => _LocalCamPreviewState();
}

class _LocalCamPreviewState extends State<_LocalCamPreview> {
  lk.EventsListener<lk.RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<lk.LocalTrackPublishedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<lk.LocalTrackUnpublishedEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  lk.VideoTrack? _findLocalVideo() {
    final lp = widget.room.localParticipant;
    if (lp == null) return null;
    for (final pub in lp.videoTrackPublications) {
      final t = pub.track;
      if (t is lk.VideoTrack) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _findLocalVideo();
    if (video == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
        ),
        child: lk.VideoTrackRenderer(
          video,
          fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirrorMode: lk.VideoViewMirrorMode.mirror,
        ),
      ),
    );
  }
}
