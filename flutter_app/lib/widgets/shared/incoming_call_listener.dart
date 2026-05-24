/// SKILL: mensaena-features
/// Incoming-Call-Listener — Root-Wrapper Widget.
///
/// Listens to TWO sources for incoming DM calls:
///   1. Supabase Realtime — Stream on dm_calls.callee_id=me filtered to
///      status='ringing'. Fires while app is open.
///   2. FCM onMessage — Foreground data-only push with type='incoming_call'.
///      Fires when notify-call Edge Function pushed but Realtime hasn't
///      propagated yet (race) or when push arrives first.
///
/// On detection: shows a full-screen, non-dismissible AlertDialog with
/// caller avatar + pulse-animation + Annehmen/Ablehnen buttons.
///   - Accept: UPDATE dm_calls SET status='active', answered_at=now()
///             + context.push('/dashboard/call/$id?room=...&peer=...')
///   - Decline: UPDATE dm_calls SET status='cancelled', ended_at=now()
///   - Timeout 45s: UPDATE dm_calls SET status='missed', ended_at=now()
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class IncomingCallListener extends ConsumerStatefulWidget {
  const IncomingCallListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState
    extends ConsumerState<IncomingCallListener> {
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<AuthState>? _authSub;
  // Deduplicate same call_id from BOTH Realtime + FCM (whoever wins first).
  final Set<String> _handledCallIds = <String>{};
  // Track currently displayed call to allow auto-close on timeout.
  String? _currentDialogCallId;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    // Re-subscribe whenever auth state changes (login/logout).
    _authSub = sb.auth.onAuthStateChange.listen((_) {
      _teardownSubs();
      _setupListeners();
    });
  }

  void _setupListeners() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    // 1. Supabase Realtime — primary source while online + app open.
    try {
      _realtimeSub = sb
          .from('dm_calls')
          .stream(primaryKey: ['id'])
          .eq('callee_id', uid)
          .listen(_handleRealtimeBatch);
    } catch (_) {/* fail-open per R5 */}

    // 2. FCM Foreground — secondary source (faster on cold-start race).
    try {
      _fcmSub = FirebaseMessaging.onMessage.listen(_handleFcmMessage);
    } catch (_) {/* fail-open per R5 */}
  }

  void _teardownSubs() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _fcmSub?.cancel();
    _fcmSub = null;
  }

  void _handleRealtimeBatch(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    for (final r in rows) {
      final id = r['id'] as String?;
      final status = r['status'] as String? ?? '';
      if (id == null || status != 'ringing') continue;
      if (_handledCallIds.contains(id)) continue;
      // Ignore stale calls older than 60s (server cleanup hasn't run yet).
      final createdAt =
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? now;
      if (now.difference(createdAt).inSeconds > 60) continue;
      _handledCallIds.add(id);
      _showCallDialog(
        callId: id,
        roomName: (r['room_name'] as String?) ?? '',
        callerId: r['caller_id'] as String?,
        conversationId: r['conversation_id'] as String?,
      );
      break;
    }
  }

  void _handleFcmMessage(RemoteMessage m) {
    if (m.data['type'] != 'incoming_call') return;
    final id = m.data['call_id'] as String?;
    if (id == null || _handledCallIds.contains(id)) return;
    _handledCallIds.add(id);
    _showCallDialog(
      callId: id,
      roomName: (m.data['room_name'] as String?) ?? '',
      callerId: m.data['caller_id'] as String?,
      callerName: m.data['caller_name'] as String?,
      conversationId: m.data['conversation_id'] as String?,
    );
  }

  Future<void> _showCallDialog({
    required String callId,
    required String roomName,
    String? callerId,
    String? callerName,
    String? conversationId,
  }) async {
    if (!mounted) return;
    // Haptic feedback only — no audio (R6: no new packages).
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 600), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 1200), HapticFeedback.heavyImpact);

    // Resolve caller profile if not pre-supplied.
    String resolvedName = callerName ?? 'Nachbar:in';
    String? avatarUrl;
    if (callerId != null) {
      try {
        final p = await sb
            .from('profiles')
            .select('display_name, name, avatar_url')
            .eq('id', callerId)
            .maybeSingle();
        if (p != null) {
          resolvedName = (p['display_name'] as String?) ??
              (p['name'] as String?) ??
              resolvedName;
          avatarUrl = p['avatar_url'] as String?;
        }
      } catch (_) {}
    }
    if (!mounted) return;

    _currentDialogCallId = callId;
    // Auto-timeout 45s → mark missed + close.
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_currentDialogCallId == callId) {
        _updateStatus(callId, 'missed');
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _currentDialogCallId = null;
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      useRootNavigator: true,
      builder: (dialogCtx) => _IncomingCallDialog(
        callerName: resolvedName,
        avatarUrl: avatarUrl,
        onAccept: () async {
          _timeoutTimer?.cancel();
          await _updateStatus(callId, 'active', answered: true);
          if (!dialogCtx.mounted) return;
          Navigator.of(dialogCtx, rootNavigator: true).pop();
          final encName = Uri.encodeComponent(resolvedName);
          final encRoom = Uri.encodeComponent(roomName);
          dialogCtx.push(
            '/dashboard/call/$callId?room=$encRoom&peer=$encName',
          );
        },
        onDecline: () async {
          _timeoutTimer?.cancel();
          await _updateStatus(callId, 'cancelled');
          if (!dialogCtx.mounted) return;
          Navigator.of(dialogCtx, rootNavigator: true).pop();
        },
      ),
    );
    _currentDialogCallId = null;
    _timeoutTimer?.cancel();
  }

  Future<void> _updateStatus(
    String callId,
    String status, {
    bool answered = false,
  }) async {
    try {
      final patch = <String, dynamic>{'status': status};
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (answered) {
        patch['answered_at'] = nowIso;
      } else if (status == 'cancelled' ||
          status == 'missed' ||
          status == 'ended') {
        patch['ended_at'] = nowIso;
      }
      await sb.from('dm_calls').update(patch).eq('id', callId);
    } catch (_) {/* fail-open per R5 */}
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _authSub?.cancel();
    _teardownSubs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────
// Incoming-Call-Dialog — fullscreen, non-dismissible, pulse-ring
// ─────────────────────────────────────────────────────────────
class _IncomingCallDialog extends StatefulWidget {
  const _IncomingCallDialog({
    required this.callerName,
    required this.onAccept,
    required this.onDecline,
    this.avatarUrl,
  });

  final String callerName;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.deep, AppColors.voidColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // Pulse-ring with avatar in center
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final scale = 1.0 + _pulse.value * 0.15;
                  final opacity = 0.5 - _pulse.value * 0.3;
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.bronze
                                    .withValues(alpha: opacity),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        _Avatar(
                          name: widget.callerName,
                          url: widget.avatarUrl,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text('call.incoming'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
              const SizedBox(height: 6),
              Text(
                widget.callerName,
                style: AppTypography.display(
                    size: 28, color: AppColors.ink, height: 1.2),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: LucideIcons.phoneOff,
                      label: 'Ablehnen',
                      color: AppColors.herzrot,
                      onTap: widget.onDecline,
                    ),
                    _ActionButton(
                      icon: LucideIcons.phoneCall,
                      label: 'Annehmen',
                      color: AppColors.leben,
                      onTap: widget.onAccept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bronze.withValues(alpha: 0.22),
        border: Border.all(color: AppColors.bronze, width: 2),
        image: (url != null && url!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url!.isEmpty)
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style:
                  AppTypography.display(size: 56, color: AppColors.bronze),
            )
          : null,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(72),
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style:
                AppTypography.label(size: 11, color: AppColors.inkSoft)),
      ],
    );
  }
}
