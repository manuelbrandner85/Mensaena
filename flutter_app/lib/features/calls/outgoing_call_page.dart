import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import '../messages/models.dart';
import 'active_call_page.dart';
import 'calls_repository.dart';
import 'models.dart';

/// Outgoing-Call-Bildschirm (Pendant zu OutgoingCallScreen.tsx).
/// Wartet via Realtime auf Status-Wechsel des dm_calls-Eintrags. Sobald
/// `active` → LiveKit-Token holen + zu ActiveCallPage navigieren. Nach 45 s
/// ohne Antwort → /api/dm-calls/missed.
class OutgoingCallPage extends ConsumerStatefulWidget {
  const OutgoingCallPage({
    super.key,
    required this.conversationId,
    required this.callee,
    required this.callType,
  });

  final String conversationId;
  final Profile callee;
  final DmCallType callType;

  @override
  ConsumerState<OutgoingCallPage> createState() => _OutgoingCallPageState();
}

class _OutgoingCallPageState extends ConsumerState<OutgoingCallPage> {
  String? _callId;
  String? _roomName;
  String? _error;
  Timer? _missedTimer;
  StreamSubscription<DmCall>? _sub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final repo = ref.read(callsRepositoryProvider);
      final res = await repo.start(
        conversationId: widget.conversationId,
        callType: widget.callType,
      );
      if (!mounted) return;
      setState(() {
        _callId = res.callId;
        _roomName = res.roomName;
      });
      _missedTimer = Timer(const Duration(seconds: 45), _onMissed);
      _sub = repo.callUpdates(res.callId).listen(_onUpdate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _onUpdate(DmCall call) async {
    if (call.status == DmCallStatus.active) {
      await _join();
    } else if (call.status == DmCallStatus.declined) {
      _showAndExit('Anruf abgelehnt');
    } else if (call.status == DmCallStatus.ended ||
        call.status == DmCallStatus.missed) {
      _showAndExit('Anruf beendet');
    }
  }

  Future<void> _join() async {
    final id = _callId;
    final room = _roomName;
    if (id == null || room == null) return;
    _missedTimer?.cancel();
    await _sub?.cancel();
    _sub = null;

    try {
      final user = ref.read(currentUserProvider);
      final res = await ref.read(callsRepositoryProvider).liveRoomToken(
            roomName: room,
            displayName: user?.userMetadata?['name'] as String?,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ActiveCallPage(
            callId: id,
            token: res.token,
            wsUrl: res.wsUrl,
            callType: widget.callType,
            peerName: widget.callee.displayName(),
          ),
        ),
      );
    } catch (e) {
      _showAndExit('Verbindung fehlgeschlagen: $e');
    }
  }

  Future<void> _onMissed() async {
    final id = _callId;
    if (id == null) return;
    try {
      await ref.read(callsRepositoryProvider).missed(id);
    } catch (_) {}
    _showAndExit('Keine Antwort');
  }

  Future<void> _cancel() async {
    HapticFeedback.mediumImpact();
    final id = _callId;
    if (id != null) {
      try {
        await ref.read(callsRepositoryProvider).cancel(id);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  void _showAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _missedTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == DmCallType.video;
    final name = widget.callee.displayName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                isVideo ? 'Mensaena · Videoanruf' : 'Mensaena · Sprachanruf',
                style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.4),
              ),
              const Spacer(flex: 2),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
                ),
                alignment: Alignment.center,
                child: widget.callee.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          widget.callee.avatarUrl!,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 28),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? (_callId == null ? 'Verbinde…' : 'Klingelt…'),
                style: TextStyle(
                  color: _error != null ? Colors.redAccent : Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Spacer(flex: 3),
              Material(
                color: const Color(0xFFC53030),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _cancel,
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Beenden',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
