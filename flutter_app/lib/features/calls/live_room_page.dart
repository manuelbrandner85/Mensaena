import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_client.dart';
import '../../core/livekit.dart';
import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// Multi-Teilnehmer Live-Room (Pendant zum Web-`LiveRoomModal.tsx`).
///
/// Nutzt das Backend-Token-Endpoint `/api/live-room/token` mit
/// `{ roomName, displayName }` und verbindet via LiveKit. Audio-only
/// Default; Camera optional togglebar.
///
/// Web-Version unterstützt zusätzlich screen-share, polls, raise-hand,
/// reactions etc. — folgt in einer separaten PR.
class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({
    super.key,
    required this.roomName,
    this.title,
  });

  final String roomName;
  final String? title;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  Room? _room;
  String? _error;
  bool _connecting = true;
  bool _micOn = true;
  bool _camOn = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _connect();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _connect() async {
    try {
      final user = sb.auth.currentUser;
      final displayName = user?.userMetadata?['name']?.toString() ??
          user?.email?.split('@').first ??
          'Mitglied';
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        '/api/live-room/token',
        body: {
          'roomName': widget.roomName,
          'displayName': displayName,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final token = data['token'] as String?;
      final url = data['url'] as String?;
      if (token == null || url == null) {
        throw Exception('Token oder URL fehlt');
      }
      final room = await ref.read(liveKitServiceProvider).connect(
            wsUrl: url,
            token: token,
            enableVideo: false,
          );
      room.addListener(_onRoomChanged);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _connecting = false;
      });
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {});
    final r = _room;
    if (r != null && r.connectionState == ConnectionState.disconnected) {
      _exit();
    }
  }

  Future<void> _toggleMic() async {
    final r = _room;
    if (r == null) return;
    HapticFeedback.lightImpact();
    final next = !_micOn;
    await r.localParticipant?.setMicrophoneEnabled(next);
    setState(() => _micOn = next);
  }

  Future<void> _toggleCam() async {
    final r = _room;
    if (r == null) return;
    HapticFeedback.lightImpact();
    final next = !_camOn;
    await r.localParticipant?.setCameraEnabled(next);
    setState(() => _camOn = next);
  }

  Future<void> _exit() async {
    _ticker?.cancel();
    final r = _room;
    if (r != null) {
      r.removeListener(_onRoomChanged);
      await r.disconnect();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _room?.removeListener(_onRoomChanged);
    _room?.disconnect();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final remotes =
        room?.remoteParticipants.values.toList(growable: false) ?? const [];
    final participantCount = (room == null ? 0 : 1) + remotes.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _exit,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? 'Live-Room',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          room == null
                              ? (_connecting
                                  ? 'Verbinde…'
                                  : (_error != null ? 'Verbindungsfehler' : ''))
                              : '$participantCount Teilnehmer · ${_format(_elapsed)}',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1F2937)),
            Expanded(
              child: _connecting
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                      ? _ErrorState(error: _error!, onRetry: _retry)
                      : _ParticipantsGrid(
                          local: room?.localParticipant,
                          remotes: remotes,
                        ),
            ),
            _ControlBar(
              micOn: _micOn,
              camOn: _camOn,
              onToggleMic: _toggleMic,
              onToggleCam: _toggleCam,
              onLeave: _exit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    await _connect();
  }
}

class _ParticipantsGrid extends StatelessWidget {
  const _ParticipantsGrid({
    required this.local,
    required this.remotes,
  });

  final LocalParticipant? local;
  final List<RemoteParticipant> remotes;

  @override
  Widget build(BuildContext context) {
    final all = <Participant>[
      if (local != null) local!,
      ...remotes,
    ];
    if (all.isEmpty) {
      return const Center(
        child: Text(
          'Keine Teilnehmer',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }
    final cols = all.length <= 1 ? 1 : (all.length <= 4 ? 2 : 3);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: all.length,
      itemBuilder: (_, i) => _ParticipantTile(participant: all[i]),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});
  final Participant participant;

  String get _displayName {
    final m = participant.metadata;
    if (m != null && m.isNotEmpty) {
      // Webserver schreibt JSON-metadata; wir nehmen identity als Fallback.
    }
    return participant.identity;
  }

  bool get _hasMic =>
      participant.audioTrackPublications.any((p) => !(p.muted));

  @override
  Widget build(BuildContext context) {
    final isLocal = participant is LocalParticipant;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal
              ? AppColors.primary500
              : const Color(0xFF374151),
          width: isLocal ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary500.withValues(alpha: 0.3),
            child: Text(
              _displayName.isNotEmpty
                  ? _displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLocal ? 'Du' : _displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            _hasMic ? Icons.mic : Icons.mic_off,
            size: 14,
            color: _hasMic ? Colors.greenAccent : const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.micOn,
    required this.camOn,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onLeave,
  });

  final bool micOn;
  final bool camOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CtrlButton(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Mute' : 'Unmute',
            onTap: onToggleMic,
            active: micOn,
          ),
          _CtrlButton(
            icon: camOn ? Icons.videocam : Icons.videocam_off,
            label: camOn ? 'Cam aus' : 'Cam ein',
            onTap: onToggleCam,
            active: camOn,
          ),
          _CtrlButton(
            icon: Icons.call_end,
            label: 'Verlassen',
            onTap: onLeave,
            active: false,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  const _CtrlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFDC2626)
        : (active ? AppColors.primary500 : const Color(0xFF374151));
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Verbindung fehlgeschlagen',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
