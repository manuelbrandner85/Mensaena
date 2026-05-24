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
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/bloom.dart';

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
      })
      ..on<lk.ParticipantDisconnectedEvent>((_) {
        if (!mounted) return;
        setState(() =>
            _participantCount = (_room?.remoteParticipants.length ?? 0) + 1);
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
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                _ActionBar(
                  micEnabled: _micEnabled,
                  camEnabled: _camEnabled,
                  enabled: _state == _RoomState.connected,
                  onMicTap: _toggleMic,
                  onCamTap: _toggleCam,
                  onLeaveTap: _leave,
                ),
              ],
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
  });

  final String channelTitle;
  final int participantCount;
  final bool connected;
  final VoidCallback onClose;

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
            iconSize: 20,
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, color: AppColors.inkSoft),
            tooltip: 'Verlassen',
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
        child: Text('Warte auf Teilnehmer:innen …',
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
  });

  final bool micEnabled;
  final bool camEnabled;
  final bool enabled;
  final VoidCallback onMicTap;
  final VoidCallback onCamTap;
  final VoidCallback onLeaveTap;

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
