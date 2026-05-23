import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Realtime-Listener auf `dm_calls` — Pendant zu Web GlobalCallListener.
/// Behebt LiveKit-Gap aus Audit Sektion A. Bei neuer INSERT row mit
/// callee_id = currentUser zeigt incoming-call-Sheet.
class IncomingCallListener extends ConsumerStatefulWidget {
  const IncomingCallListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState
    extends ConsumerState<IncomingCallListener> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  final Set<String> _handled = {};

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      _sub = sb
          .from('dm_calls')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((rows) {
            for (final r in rows) {
              final id = r['id'] as String?;
              if (id == null || _handled.contains(id)) continue;
              if (r['callee_id'] != uid) continue;
              final status = r['status'] as String? ?? '';
              if (status != 'ringing') continue;
              final age = DateTime.now().difference(
                  DateTime.tryParse(r['created_at'] as String? ?? '') ??
                      DateTime.now());
              // Nur Anrufe der letzten 60s — alte ignorieren
              if (age.inSeconds > 60) continue;
              _handled.add(id);
              _showIncomingCall(r);
              break;
            }
          });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _showIncomingCall(Map<String, dynamic> call) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    final callerId = call['caller_id'] as String?;
    final callId = call['id'] as String;

    // Caller-Profile laden
    String callerName = 'Nachbar:in';
    String? avatarUrl;
    if (callerId != null) {
      try {
        final p = await sb
            .from('profiles')
            .select('display_name, name, avatar_url')
            .eq('id', callerId)
            .maybeSingle();
        if (p != null) {
          callerName = (p['display_name'] as String?) ??
              (p['name'] as String?) ??
              callerName;
          avatarUrl = p['avatar_url'] as String?;
        }
      } catch (_) {}
    }
    if (!mounted) return;

    // Vollbild-Sheet mit Annehmen/Ablehnen
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _IncomingCallSheet(
        callId: callId,
        callerName: callerName,
        avatarUrl: avatarUrl,
        onAccept: () async {
          await _updateStatus(callId, 'accepted');
          if (!mounted) return;
          Navigator.pop(context);
          // Navigate to call screen (chat with conv id)
          final conv = call['conversation_id'] as String?;
          if (conv != null && mounted) {
            context.go('/dashboard/chat?conv=$conv');
          }
        },
        onDecline: () async {
          await _updateStatus(callId, 'declined');
          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _updateStatus(String callId, String status) async {
    try {
      await sb.from('dm_calls').update({
        'status': status,
        if (status == 'ended' || status == 'declined')
          'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingCallSheet extends StatefulWidget {
  const _IncomingCallSheet({
    required this.callId,
    required this.callerName,
    required this.onAccept,
    required this.onDecline,
    this.avatarUrl,
  });

  final String callId;
  final String callerName;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_IncomingCallSheet> createState() => _IncomingCallSheetState();
}

class _IncomingCallSheetState extends State<_IncomingCallSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deep,
            AppColors.voidColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'EINGEHENDER ANRUF',
              style: AppTypography.label(
                size: 9,
                color: AppColors.bronze,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 32),
            // Pulse-Avatar
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final wave = _ctrl.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Container(
                        width: 130 + (wave + i * 0.5) % 1.0 * 60,
                        height: 130 + (wave + i * 0.5) % 1.0 * 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.leben.withValues(
                                alpha: 0.5 * (1 - ((wave + i * 0.5) % 1.0))),
                            width: 2,
                          ),
                        ),
                      ),
                    Container(
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.leben.withValues(alpha: 0.6),
                            width: 2),
                      ),
                      child: widget.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                widget.avatarUrl!,
                                width: 116,
                                height: 116,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  widget.callerName[0].toUpperCase(),
                                  style: AppTypography.display(
                                    size: 48,
                                    color: AppColors.bronze,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              widget.callerName[0].toUpperCase(),
                              style: AppTypography.display(
                                size: 48,
                                color: AppColors.bronze,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              widget.callerName,
              style: AppTypography.display(
                size: 28,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'möchte dich anrufen.',
              style: AppTypography.body(
                size: 14,
                color: AppColors.mute,
              ),
            ),
            const Spacer(),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 40, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleAction(
                    icon: LucideIcons.phoneOff,
                    color: AppColors.herzrot,
                    label: 'Ablehnen',
                    onTap: widget.onDecline,
                  ),
                  _CircleAction(
                    icon: LucideIcons.phone,
                    color: AppColors.leben,
                    label: 'Annehmen',
                    onTap: widget.onAccept,
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
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: AppColors.ink, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: AppTypography.label(
            size: 10,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}
