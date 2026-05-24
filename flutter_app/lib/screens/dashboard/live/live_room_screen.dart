import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// flutter_webrtc kommt transitiv via livekit_client (patched 0.13.1+hotfix.1
// per CI-Script). Direkter Import nur für den RTCVideoViewObjectFit-Enum.
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
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
  // Default-Tracks: Mic AN (du willst gehört werden), Kamera AUS (Privacy).
  // User toggelt explizit via _SquareAction.
  bool _micEnabled = true;
  bool _camEnabled = false;
  String? _error;
  int _participantCount = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    if (widget.isHost) {
      // Nur Mikro requesten — Kamera wird beim ersten _toggleCam abgefragt.
      final mic = await Permission.microphone.request();
      if (mic.isDenied || mic.isPermanentlyDenied) {
        if (!mounted) return;
        setState(() {
          _state = _RoomState.failed;
          _error = 'Mikrofon-Berechtigung verweigert.';
        });
        return;
      }
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
        // Standard: nur Mikro an. Kamera lässt User später aktiv ein.
        await room.localParticipant?.setMicrophoneEnabled(_micEnabled);
        // Kamera bewusst NICHT auto-enable.
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
    if (next) {
      // Permission erst beim ersten Aktivieren der Kamera requesten.
      final cam = await Permission.camera.request();
      if (cam.isDenied || cam.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Kamera-Berechtigung verweigert.',
              style: AppTypography.body(size: 13, color: AppColors.ink)),
        ));
        return;
      }
    }
    try {
      await lp.setCameraEnabled(next);
      if (mounted) setState(() => _camEnabled = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Kamera-Fehler: $e',
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
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
    // BUG-FIX #1: Host-Cleanup auch bei App-Close oder Navigation-Pop.
    // Vorher: dispose() schloss nur Room + Listener, aber live_rooms.ended_at
    // wurde nur in _leave() gesetzt. Bei App-Kill / Hot-Reload / Force-Navigate
    // blieb live_rooms.status='live' fuer immer → Ghost-Banner.
    if (widget.isHost) {
      // Fire-and-forget — Future kann nicht awaited werden in dispose.
      LiveStreamService.endChannelStream(widget.roomName);
    }
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

/// Wickelt jeden Participant in StreamBuilder über RoomEvents damit
/// neue Track-Publikationen (z. B. nach setCameraEnabled true) sofort
/// neu gerendert werden — sonst bleibt der Slot leer/grau.
class _RoomGrid extends StatefulWidget {
  const _RoomGrid({required this.room});
  final lk.Room? room;

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
        ..on<lk.TrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        })
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
        })
        ..on<lk.LocalTrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.LocalTrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  /// Findet einen sichtbaren Video-Track:
  ///   * Local-Participant: nutzt nur unmuted Local-Publication.
  ///   * Remote-Participant: nutzt subscribed + unmuted.
  /// Liefert null wenn keiner verfügbar → wir zeigen Avatar-Fallback.
  lk.VideoTrack? _videoTrackFor(lk.Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.muted) continue;
      final track = pub.track;
      if (track == null) continue;
      if (track is! lk.VideoTrack) continue;
      if (p is lk.RemoteParticipant && !pub.subscribed) continue;
      return track;
    }
    return null;
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
        final videoTrack = _videoTrackFor(p);
        final name = p.name.isNotEmpty ? p.name : p.identity;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (videoTrack != null)
                lk.VideoTrackRenderer(
                  videoTrack,
                  fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _AvatarFallback(name: name),
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
                    name,
                    style: AppTypography.body(
                        size: 11, color: AppColors.ink),
                  ),
                ),
              ),
              if (videoTrack == null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.voidColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(LucideIcons.videoOff,
                        size: 12, color: AppColors.mute),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.25),
            AppColors.deep,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bronze.withValues(alpha: 0.18),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.5), width: 2),
        ),
        child: Text(
          initial,
          style: AppTypography.display(size: 38, color: AppColors.bronze),
        ),
      ),
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
