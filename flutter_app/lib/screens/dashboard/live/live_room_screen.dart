import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/livekit_token_service.dart';
import '../../../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Live-Room fuer Community-Channels (Mehr-Teilnehmer LiveKit-Stream).
/// Host kann publishen (cam+mic), Gaeste nur subscribe.
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
  bool _camEnabled = true;
  String? _error;
  int _participantCount = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    if (widget.isHost) {
      final mic = await Permission.microphone.request();
      if (mic.isDenied || mic.isPermanentlyDenied) {
        if (!mounted) return;
        setState(() {
          _state = _RoomState.failed;
          _error = 'Mikrofon-Berechtigung verweigert.';
        });
        return;
      }
      await Permission.camera.request();
    }

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

    final ({String token, String url}) tok;
    try {
      tok = await LivekitTokenService.fetch(
        roomName: widget.roomName,
        displayName: myName,
        canPublish: widget.isHost,
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
      ..on<lk.ParticipantConnectedEvent>((_) {
        if (!mounted) return;
        setState(() =>
            _participantCount = (_room?.remoteParticipants.length ?? 0) + 1);
      })
      ..on<lk.ParticipantDisconnectedEvent>((_) {
        if (!mounted) return;
        setState(() =>
            _participantCount = (_room?.remoteParticipants.length ?? 0) + 1);
      });

    try {
      await room.connect(tok.url, tok.token);
      if (widget.isHost) {
        await room.localParticipant?.setMicrophoneEnabled(true);
        await room.localParticipant?.setCameraEnabled(true);
      }
      if (!mounted) return;
      setState(() {
        _state = _RoomState.connected;
        _participantCount = room.remoteParticipants.length + 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.failed;
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
    final next = !_camEnabled;
    await lp.setCameraEnabled(next);
    setState(() => _camEnabled = next);
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
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.herzrot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('LIVE',
                            style: AppTypography.label(
                                size: 9, color: AppColors.herzrotWarm)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.channelTitle.isEmpty
                          ? widget.roomName
                          : widget.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 15,
                          color: AppColors.ink,
                          weight: FontWeight.w700),
                    ),
                  ),
                  if (_state == _RoomState.connected) ...[
                    const Icon(LucideIcons.users,
                        size: 12, color: AppColors.mute),
                    const SizedBox(width: 3),
                    Text('$_participantCount',
                        style: AppTypography.label(
                            size: 10, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            // Video-Bereich
            Expanded(
              child: _state == _RoomState.connecting
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.bronze))
                  : _state == _RoomState.failed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.alertTriangle,
                                    size: 32,
                                    color: AppColors.herzrotWarm),
                                const SizedBox(height: 10),
                                Text('Verbindung fehlgeschlagen',
                                    style: AppTypography.body(
                                        size: 14,
                                        color: AppColors.ink,
                                        weight: FontWeight.w700)),
                                if (_error != null) ...[
                                  const SizedBox(height: 6),
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.body(
                                          size: 12,
                                          color: AppColors.inkSoft)),
                                ],
                              ],
                            ),
                          ),
                        )
                      : _RoomGrid(room: _room),
            ),
            // Action-Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.isHost) ...[
                    _SquareAction(
                      icon: _micEnabled
                          ? LucideIcons.mic
                          : LucideIcons.micOff,
                      label: 'Mikro',
                      active: _micEnabled,
                      onTap: _state == _RoomState.connected ? _toggleMic : null,
                    ),
                    _SquareAction(
                      icon: _camEnabled
                          ? LucideIcons.video
                          : LucideIcons.videoOff,
                      label: 'Kamera',
                      active: _camEnabled,
                      onTap: _state == _RoomState.connected ? _toggleCam : null,
                    ),
                  ],
                  _SquareAction(
                    icon: LucideIcons.x,
                    label: widget.isHost ? 'Beenden' : 'Verlassen',
                    active: false,
                    danger: true,
                    onTap: _leave,
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

class _RoomGrid extends StatelessWidget {
  const _RoomGrid({required this.room});
  final lk.Room? room;

  @override
  Widget build(BuildContext context) {
    final r = room;
    if (r == null) return const SizedBox.shrink();
    final participants = <lk.Participant>[
      if (r.localParticipant != null) r.localParticipant!,
      ...r.remoteParticipants.values,
    ];
    if (participants.isEmpty) {
      return Center(
        child: Text('Warte auf Teilnehmer:innen…',
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 2 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 4 / 3,
      ),
      itemCount: participants.length,
      itemBuilder: (context, i) {
        final p = participants[i];
        final track = p.videoTrackPublications
            .firstWhere(
              (t) => t.subscribed && !(t.muted),
              orElse: () => p.videoTrackPublications.isEmpty
                  ? throw StateError('no track')
                  : p.videoTrackPublications.first,
            );
        return Container(
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (track.track is lk.VideoTrack)
                lk.VideoTrackRenderer(track.track! as lk.VideoTrack)
              else
                Center(
                  child: Icon(LucideIcons.user,
                      size: 40, color: AppColors.mute),
                ),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.voidColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.name.isNotEmpty ? p.name : p.identity,
                    style: AppTypography.body(
                        size: 11, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.herzrot
        : (active ? AppColors.bronze : AppColors.mute);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: AppTypography.label(size: 9, color: AppColors.inkSoft)),
      ],
    );
  }
}
