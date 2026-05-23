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

enum _CallState { connecting, connected, ended, failed }

class _CallScreenState extends ConsumerState<CallScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  _CallState _state = _CallState.connecting;
  bool _micEnabled = true;
  bool _camEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
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
        setState(() => _state = _CallState.ended);
      });

    try {
      await room.connect(tok.url, tok.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() => _state = _CallState.connected);
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
            // Peer-Avatar (Platzhalter — TODO: aus Profile laden)
            Container(
              width: 140,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.4),
                    width: 2),
              ),
              child: Text(
                widget.peerName.isNotEmpty
                    ? widget.peerName[0].toUpperCase()
                    : '?',
                style: AppTypography.display(
                    size: 56, color: AppColors.bronze),
              ),
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
            // Action Bar
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
        ),
      ),
    );
  }

  String _subtitle() {
    switch (_state) {
      case _CallState.connecting:
        return 'Verbinde…';
      case _CallState.connected:
        return 'Verbunden';
      case _CallState.ended:
        return 'Beendet';
      case _CallState.failed:
        return 'Verbindung fehlgeschlagen';
    }
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
