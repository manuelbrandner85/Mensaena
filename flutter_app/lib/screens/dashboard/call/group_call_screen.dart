/// SKILL: mensaena-features (Phase 3 F13)
/// Group-Call-Screen — bis 4 Teilnehmer, kein Ringing/CallKit. Beitritt
/// erfolgt via Tap auf [CALL_INVITE]-Message-Bubble im Chat.
/// Audio-first, simples Grid-Layout (1 / 2-Spalten).
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/livekit_token_service.dart';
import '../../../services/supabase_service.dart';

class GroupCallScreen extends ConsumerStatefulWidget {
  const GroupCallScreen({required this.roomName, super.key});
  final String roomName;

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _connecting = true;
  bool _micEnabled = true;
  String? _error;
  final List<lk.RemoteParticipant> _remoteParticipants = [];
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  // ValueNotifier statt setState für die 1-Hz-Duration → kein
  // Vollscreen-Rebuild jede Sekunde.
  final ValueNotifier<Duration> _elapsed =
      ValueNotifier<Duration>(Duration.zero);

  // F13: Cap auf 10 — größer als 4 packt der Mobile-Mic-Mix qualitativ
  // schon spürbar an, aber 10 ist mit Mute-Disziplin praktikabel.
  static const _maxParticipants = 10;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final me = SupabaseService.currentUser;
      final displayName =
          me?.userMetadata?['display_name'] as String? ?? 'Mitglied';
      final tok = await LivekitTokenService.fetch(
        roomName: widget.roomName,
        displayName: displayName,
      );
      final room = lk.Room();
      _room = room;
      final listener = room.createListener();
      _listener = listener;
      listener
        ..on<lk.ParticipantConnectedEvent>((ev) {
          if (!mounted) return;
          // _maxParticipants-Cap: über N kicken wir den Späteren wieder raus.
          // Sicheres Soft-Limit clientseitig — Server-Reject wäre nice-to-have.
          if (_remoteParticipants.length + 1 >= _maxParticipants) {
            // ignore, anderen client zeigt dann "Voll" über Tile-Layout
            return;
          }
          setState(() {
            _remoteParticipants
              ..removeWhere((p) => p.identity == ev.participant.identity)
              ..add(ev.participant);
          });
        })
        ..on<lk.ParticipantDisconnectedEvent>((ev) {
          if (!mounted) return;
          setState(() => _remoteParticipants
              .removeWhere((p) => p.identity == ev.participant.identity));
        })
        ..on<lk.RoomDisconnectedEvent>((_) async {
          if (mounted) _hangUp();
        })
        // Mute-Status-Sync: TrackMuted/Unmuted müssen ein Rebuild auslösen
        // damit die Mic-Icons pro Tile aktuell sind.
        ..on<lk.TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        });
      // Maximalkapazität vor Connect prüfen — die Liste ist VOR connect
      // leer, aber ein 2. SetState nach connect könnte rauskicken; wir
      // bleiben hier optimistisch und vertrauen dem Server-Side-Limit
      // wenn vorhanden, sonst macht das Soft-Limit oben Schluss.
      await room.connect(tok.url, tok.token);
      final currentRemotes = room.remoteParticipants.values.toList();
      if (currentRemotes.length >= _maxParticipants) {
        // Bereits voll — Token-Bypass nutzlos, sauber wieder disconnecten.
        await room.disconnect();
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _error = 'group_call.full'.tr();
        });
        return;
      }
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _remoteParticipants
          ..clear()
          ..addAll(currentRemotes);
      });
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _elapsed.value = _stopwatch.elapsed;
      });
    } on LivekitTokenError catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'group_call.connectFailed'.tr();
      });
    }
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_micEnabled;
    await lp.setMicrophoneEnabled(next);
    if (mounted) setState(() => _micEnabled = next);
  }

  Future<void> _hangUp() async {
    _ticker?.cancel();
    _stopwatch.stop();
    try {
      await _listener?.dispose();
    } catch (_) {}
    _listener = null;
    try {
      await _room?.disconnect();
    } catch (_) {}
    _room = null;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _elapsed.dispose();
    try {
      _listener?.dispose();
    } catch (_) {}
    try {
      _room?.disconnect();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCount = _remoteParticipants.length + 1; // +me
    final remaining = _maxParticipants - allCount;
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                const Icon(LucideIcons.users,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text(
                  'group_call.title'.tr(),
                  style: AppTypography.body(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700),
                ),
                const Spacer(),
                if (_stopwatch.isRunning)
                  ValueListenableBuilder<Duration>(
                    valueListenable: _elapsed,
                    builder: (_, d, __) => Text(
                      _formatDuration(d),
                      style: AppTypography.mono(
                          size: 12, color: AppColors.amber),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: _connecting
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.amber),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.herzrotWarm),
                            ),
                          ),
                        )
                      : _buildGrid(allCount, remaining),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleAction(
                    icon: _micEnabled
                        ? LucideIcons.mic
                        : LucideIcons.micOff,
                    color: _micEnabled
                        ? AppColors.bronze
                        : AppColors.herzrotWarm,
                    onTap: _toggleMic,
                  ),
                  _CircleAction(
                    icon: LucideIcons.phoneOff,
                    color: AppColors.herzrot,
                    big: true,
                    onTap: _hangUp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(int allCount, int remaining) {
    final me = SupabaseService.currentUser;
    final myName =
        (me?.userMetadata?['display_name'] as String?) ?? 'group_call.you'.tr();
    final tiles = <Widget>[
      _ParticipantTile(name: myName, isMe: true, micOn: _micEnabled),
      for (final p in _remoteParticipants)
        _ParticipantTile(
          name: p.name.isEmpty ? p.identity : p.name,
          isMe: false,
          micOn: p.isMicrophoneEnabled(),
        ),
      for (var i = 0; i < remaining; i++) const _EmptySlot(),
    ];
    // Spalten skalieren mit Teilnehmerzahl: 1 (solo), 2 (≤4), 3 (≥5).
    final cols = allCount <= 1 ? 1 : (allCount <= 4 ? 2 : 3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: cols == 1 ? 0.9 : (cols == 2 ? 0.85 : 0.75),
        children: tiles,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.name,
    required this.isMe,
    required this.micOn,
  });
  final String name;
  final bool isMe;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [
          AppColors.bronze.withValues(alpha: 0.18),
          AppColors.elevated.withValues(alpha: 0.7),
        ]),
        border: Border.all(
          color: (isMe ? AppColors.amber : AppColors.bronze)
              .withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: AppTypography.display(
                        size: 26, color: AppColors.bronze),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMe ? 'group_call.you'.tr() : name,
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.voidColor.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                micOn ? LucideIcons.mic : LucideIcons.micOff,
                size: 12,
                color: micOn ? AppColors.leben : AppColors.herzrotWarm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        border: Border.all(
          color: AppColors.line,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(LucideIcons.userPlus,
            size: 28, color: AppColors.mute.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.big = false,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 64.0 : 52.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: big ? 24 : 20),
      ),
    );
  }
}
