import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_call_page.dart';
import 'calls_repository.dart';
import 'models.dart';

/// Incoming-Call-Bildschirm (Pendant zu IncomingCallScreen.tsx).
/// Zeigt Caller-Profil + Annehmen/Ablehnen. Nach 45 s ohne Aktion → lokal
/// schließen (Caller-Seite markiert serverseitig als missed).
class IncomingCallPage extends ConsumerStatefulWidget {
  const IncomingCallPage({super.key, required this.call});
  final DmCall call;

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage> {
  Timer? _timeout;
  Timer? _vibrate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 45), _autoDismiss);
    _vibrate = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
    });
    HapticFeedback.heavyImpact();
  }

  void _autoDismiss() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    _timeout?.cancel();
    _vibrate?.cancel();
    try {
      final res = await ref
          .read(callsRepositoryProvider)
          .answer(widget.call.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ActiveCallPage(
            callId: widget.call.id,
            token: res.token,
            wsUrl: res.wsUrl,
            callType: widget.call.callType,
            peerName: widget.call.callerProfile?.displayName() ?? 'Anrufer',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Annahme fehlgeschlagen: $e')),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    _timeout?.cancel();
    _vibrate?.cancel();
    try {
      await ref.read(callsRepositoryProvider).decline(widget.call.id);
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _vibrate?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.call.callerProfile;
    final name = caller?.displayName() ?? 'Anrufer';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isVideo = widget.call.isVideo;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              Text(
                isVideo
                    ? 'Eingehender Videoanruf'
                    : 'Eingehender Sprachanruf',
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
                child: caller?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          caller!.avatarUrl!,
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
              const Text(
                'ruft an…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: const Color(0xFFC53030),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _decline,
                          child: const Padding(
                            padding: EdgeInsets.all(22),
                            child: Icon(Icons.call_end, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Ablehnen', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: const Color(0xFF10B981),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _accept,
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Icon(
                              isVideo ? Icons.videocam : Icons.call,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Annehmen', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
