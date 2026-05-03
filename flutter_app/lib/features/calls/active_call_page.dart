import 'dart:async';

// `ConnectionState` ist sowohl in flutter/material als auch in livekit_client
// definiert – wir nutzen ausschliesslich die LiveKit-Variante (Room-Status).
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/livekit.dart';
import '../../theme/app_colors.dart';
import 'calls_repository.dart';
import 'models.dart';

/// Aktiver 1:1-Call (Pendant zu LiveRoomModal.tsx).
/// Mikrofon-Toggle, optional Kamera-Toggle (bei Video-Call), Lautsprecher,
/// Hangup. Räumt Room + dm_calls beim Verlassen auf.
class ActiveCallPage extends ConsumerStatefulWidget {
  const ActiveCallPage({
    super.key,
    required this.callId,
    required this.token,
    required this.wsUrl,
    required this.callType,
    required this.peerName,
  });

  final String callId;
  final String token;
  final String wsUrl;
  final DmCallType callType;
  final String peerName;

  @override
  ConsumerState<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends ConsumerState<ActiveCallPage> {
  Room? _room;
  String? _error;
  bool _micOn = true;
  bool _camOn = false;
  bool _speakerOn = true;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  RemoteParticipant? _peer;

  bool get _isVideo => widget.callType == DmCallType.video;

  @override
  void initState() {
    super.initState();
    _camOn = _isVideo;
    _connect();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _connect() async {
    try {
      final room = await ref.read(liveKitServiceProvider).connect(
            wsUrl: widget.wsUrl,
            token: widget.token,
            enableVideo: _isVideo,
          );
      room.addListener(_onRoomChanged);
      // Suche bereits angeschlossenen Peer
      _updatePeerFromRoom(room);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() => _room = room);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    final r = _room;
    if (r == null) return;
    _updatePeerFromRoom(r);
    if (r.connectionState == ConnectionState.disconnected) {
      _exit();
    }
  }

  void _updatePeerFromRoom(Room r) {
    final remotes = r.remoteParticipants.values;
    final next = remotes.isEmpty ? null : remotes.first;
    if (next == _peer) return;
    setState(() => _peer = next);
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_micOn;
    await lp.setMicrophoneEnabled(next);
    setState(() => _micOn = next);
  }

  Future<void> _toggleCam() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_camOn;
    await lp.setCameraEnabled(next);
    setState(() => _camOn = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    try {
      await Hardware.instance.setSpeakerphoneOn(next);
    } catch (_) {
      // Auf Desktop irrelevant.
    }
    setState(() => _speakerOn = next);
  }

  Future<void> _hangup() async {
    HapticFeedback.mediumImpact();
    await ref.read(callsRepositoryProvider).end(widget.callId);
    _exit();
  }

  void _exit() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final r = _room;
    if (r != null) {
      r.removeListener(_onRoomChanged);
      r.disconnect();
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2A2E),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isVideo && _peer != null) _PeerVideo(peer: _peer!),
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Header(
                    name: widget.peerName,
                    elapsed: _elapsed,
                    isVideo: _isVideo,
                    error: _error,
                    connecting: _room == null && _error == null,
                  ),
                  if (!_isVideo || _peer == null)
                    _AvatarBlock(name: widget.peerName, isVideo: _isVideo),
                  _Controls(
                    micOn: _micOn,
                    camOn: _camOn,
                    speakerOn: _speakerOn,
                    isVideo: _isVideo,
                    onMic: _toggleMic,
                    onCam: _isVideo ? _toggleCam : null,
                    onSpeaker: _toggleSpeaker,
                    onHangup: _hangup,
                  ),
                ],
              ),
            ),
            if (_isVideo && _camOn) _SelfPreview(room: _room),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.elapsed,
    required this.isVideo,
    required this.connecting,
    this.error,
  });

  final String name;
  final Duration elapsed;
  final bool isVideo;
  final bool connecting;
  final String? error;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVideo ? 'Mensaena · Videoanruf' : 'Mensaena · Sprachanruf',
            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            error != null
                ? 'Verbindung fehlgeschlagen'
                : connecting
                    ? 'Verbinde…'
                    : _format(elapsed),
            style: TextStyle(
              color: error != null ? Colors.redAccent : Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.name, required this.isVideo});
  final String name;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.micOn,
    required this.camOn,
    required this.speakerOn,
    required this.isVideo,
    required this.onMic,
    required this.onSpeaker,
    required this.onHangup,
    this.onCam,
  });

  final bool micOn;
  final bool camOn;
  final bool speakerOn;
  final bool isVideo;
  final VoidCallback onMic;
  final VoidCallback? onCam;
  final VoidCallback onSpeaker;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Mute' : 'Stumm',
            active: !micOn,
            onTap: onMic,
          ),
          if (isVideo && onCam != null)
            _RoundButton(
              icon: camOn ? Icons.videocam : Icons.videocam_off,
              label: camOn ? 'Kamera' : 'Kamera aus',
              active: !camOn,
              onTap: onCam!,
            ),
          _RoundButton(
            icon: speakerOn ? Icons.volume_up : Icons.volume_off,
            label: speakerOn ? 'Lautspr.' : 'Hörer',
            active: !speakerOn,
            onTap: onSpeaker,
          ),
          _RoundButton(
            icon: Icons.call_end,
            label: 'Auflegen',
            color: const Color(0xFFC53030),
            onTap: onHangup,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = color ??
        (active ? Colors.white : Colors.white.withValues(alpha: 0.15));
    final fg = color != null
        ? Colors.white
        : (active ? AppColors.ink800 : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: fg, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _PeerVideo extends StatelessWidget {
  const _PeerVideo({required this.peer});
  final RemoteParticipant peer;

  @override
  Widget build(BuildContext context) {
    final track = peer.videoTrackPublications
        .where((p) => p.subscribed && p.track != null)
        .map((p) => p.track)
        .whereType<VideoTrack>()
        .firstOrNull;
    if (track == null) return const SizedBox.shrink();
    // `fit` lassen wir weg – livekit_client 2.2.4 nutzt RTCVideoViewObjectFit
    // (aus flutter_webrtc), der Default rendert das Peer-Video bildfüllend.
    return Positioned.fill(
      child: VideoTrackRenderer(track),
    );
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({required this.room});
  final Room? room;

  @override
  Widget build(BuildContext context) {
    final track = room?.localParticipant?.videoTrackPublications
        .map((p) => p.track)
        .whereType<VideoTrack>()
        .firstOrNull;
    if (track == null) return const SizedBox.shrink();
    return Positioned(
      top: 88,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 110,
          height: 160,
          child: VideoTrackRenderer(track, mirrorMode: VideoViewMirrorMode.mirror),
        ),
      ),
    );
  }
}

