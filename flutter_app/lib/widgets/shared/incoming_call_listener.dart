/// SKILL: mensaena-features
/// Incoming-Call-Listener — Foreground-Watcher fuer Ringing-Signale.
///
/// Aufgabe nur: Realtime + FCM-onMessage hoeren waehrend App offen ist,
/// und bei eingehendem Ringing-Signal die native CallKit-UI triggern.
/// Der eigentliche Accept/Decline/Timeout/Ended-Flow lebt im globalen
/// `CallEventBus` (main.dart), damit Cold-Start-Accepts nicht verloren
/// gehen.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../config/routes/app_router.dart' show rootNavigatorKey;
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/call_busy_state.dart';
import '../../services/call_event_bus.dart';
import '../../services/callkit_service.dart';
import '../../services/dm_call_service.dart';
import '../../services/incoming_call_overlay.dart';
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
  StreamSubscription<CallContext>? _postDeclineSub;
  // Deduplicate same call_id from Realtime + FCM (whoever wins first).
  final Set<String> _handledCallIds = <String>{};

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _postDeclineSub =
        CallEventBus.onPostDecline.listen(_showQuickReplySheet);
    _authSub = sb.auth.onAuthStateChange.listen((_) {
      _teardownSubs();
      _handledCallIds.clear();
      CallEventBus.clearHandled();
      _setupListeners();
    });
  }

  /// Nach Decline: kleines Bottom-Sheet mit 3 Quick-Reply-Buttons.
  /// User-Tap → sendet Auto-Chat-Message + erspart "verpasst"-Wirkung.
  Future<void> _showQuickReplySheet(CallContext ctx) async {
    if (ctx.conversationId == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    final overlayContext = nav.context;
    if (!overlayContext.mounted) return;
    // Kurz warten damit CallKit-UI sicher verschwunden ist.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!overlayContext.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: overlayContext,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final replies = <String>[
          'quickReply.in5Min'.tr(),
          'quickReply.busy'.tr(),
          'quickReply.willCallBack'.tr(),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.messageSquare,
                        size: 18, color: AppColors.bronze),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'quickReply.title'
                            .tr(namedArgs: {'name': ctx.callerName}),
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('quickReply.subtitle'.tr(),
                    style: AppTypography.caption()),
                const SizedBox(height: 14),
                for (final r in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx, r),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: AppColors.bronze,
                          side: BorderSide(
                              color: AppColors.bronze
                                  .withValues(alpha: 0.5)),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(r,
                            style: AppTypography.body(
                                size: 14, color: AppColors.ink)),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: Text('common.skip'.tr()),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    final me = SupabaseService.currentUser?.id;
    if (me == null) return;
    try {
      await sb.from('messages').insert({
        'conversation_id': ctx.conversationId,
        'sender_id': me,
        'content': picked,
      });
    } catch (_) {}
  }

  void _setupListeners() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    // Cold-Start-Race verhindern: wenn der User den Anruf vom Sperrbildschirm
    // aus angenommen hat, läuft die App frisch hoch, die dm_calls-Row steht
    // aber noch auf 'ringing' (DB-Update von _onAccept ist fire-and-forget).
    // Erst die nativen Active-Calls abfragen und ihre IDs in beide Dedupe-
    // Sets stecken, damit der Initial-Snapshot des Realtime-Streams NICHT
    // ein zweites Popup auslöst.
    unawaited(_seedHandledFromActiveCalls().then((_) {
      if (!mounted) return;
      try {
        _realtimeSub = sb
            .from('dm_calls')
            .stream(primaryKey: ['id'])
            .eq('callee_id', uid)
            .listen(
              _handleRealtimeBatch,
              onError: (_) {/* swallow timeouts / network drops */},
              cancelOnError: false,
            );
      } catch (_) {/* fail-open */}

      try {
        _fcmSub = FirebaseMessaging.onMessage.listen(
          _handleFcmMessage,
          onError: (_) {},
          cancelOnError: false,
        );
      } catch (_) {/* fail-open */}
    }));
  }

  Future<void> _seedHandledFromActiveCalls() async {
    try {
      final calls = await CallkitService.activeCalls();
      if (calls is! List) return;
      for (final c in calls) {
        if (c is! Map) continue;
        final id = c['id'] as String?;
        final state = c['state'] as String?;
        if (id == null) continue;
        if (state == 'accepted' || state == 'connected') {
          _handledCallIds.add(id);
          CallEventBus.recordHandledAccept(id);
        }
      }
    } catch (_) {/* non-fatal */}
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
      if (id == null) continue;
      // Wenn Anrufer cancelt waehrend die UI rauscht → CallKit beenden.
      if (status == 'cancelled' || status == 'ended' || status == 'missed') {
        if (_handledCallIds.contains(id)) {
          CallkitService.endCall(id);
          unawaited(IncomingCallOverlay.close());
        }
        continue;
      }
      if (status != 'ringing') continue;
      if (_handledCallIds.contains(id) ||
          CallEventBus.isHandledAccept(id)) continue;
      // Stale-Call-Filter — der WICHTIGE Punkt: wir prüfen sowohl
      // created_at-Alter ALS AUCH ended_at. Vorher wurde NUR created_at
      // gegen 60 s geprüft → wenn die App nach Anruf-Ende geöffnet wurde,
      // ploppte ein längst beendeter Anruf auf, weil Realtime den letzten
      // Snapshot mitlieferte.
      final endedAt = r['ended_at'] as String?;
      if (endedAt != null && endedAt.isNotEmpty) continue;
      final createdAt =
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? now;
      // 50 s = 45 s Klingelfrist + Puffer; danach hat der Caller eh aufgegeben.
      if (now.difference(createdAt).inSeconds > 50) continue;
      _handledCallIds.add(id);
      _triggerIncoming(
        callId: id,
        roomName: (r['room_name'] as String?) ?? '',
        callerId: r['caller_id'] as String?,
        conversationId: r['conversation_id'] as String?,
        callType: (r['call_type'] as String?) ?? 'audio',
      );
    }
  }

  void _handleFcmMessage(RemoteMessage m) {
    if (m.data['type'] != 'incoming_call') return;
    final id = m.data['call_id'] as String?;
    if (id == null ||
        _handledCallIds.contains(id) ||
        CallEventBus.isHandledAccept(id)) return;
    _handledCallIds.add(id);
    _triggerIncoming(
      callId: id,
      roomName: (m.data['room_name'] as String?) ?? '',
      callerId: m.data['caller_id'] as String?,
      callerName: m.data['caller_name'] as String?,
      callerAvatar: m.data['caller_avatar'] as String?,
      conversationId: m.data['conversation_id'] as String?,
      callType: (m.data['call_type'] as String?) ?? 'audio',
    );
  }

  Future<void> _triggerIncoming({
    required String callId,
    required String roomName,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? conversationId,
    String callType = 'audio',
  }) async {
    // Punkt 4: Wenn der User bereits in einem Call/Stream ist, den
    // eingehenden Anruf als "besetzt" ablehnen statt ihn aus dem laufenden
    // Call/Stream zu werfen. Kein CallKit-Fullscreen, keine Navigation.
    if (CallBusyState.busy) {
      unawaited(DmCallService.declineBusy(callId));
      return;
    }

    String resolvedName = callerName ?? 'Nachbar:in';
    String? avatarUrl = callerAvatar;
    if (callerId != null && (callerName == null || avatarUrl == null)) {
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
          avatarUrl ??= p['avatar_url'] as String?;
        }
      } catch (_) {}
    }

    // Metadata an CallEventBus geben fuer Accept-Navigation.
    CallEventBus.recordContext(CallContext(
      callId: callId,
      roomName: roomName,
      callerName: resolvedName,
      conversationId: conversationId,
    ));

    try {
      await CallkitService.showIncoming(
        callId: callId,
        callerName: resolvedName,
        callerAvatar: avatarUrl,
        roomName: roomName,
        conversationId: conversationId,
        callerId: callerId,
        callType: callType,
      );
    } catch (_) {
      _handledCallIds.remove(callId);
    }
    // Zusätzlich Vollbild-System-Overlay zeigen (Samsung One UI demotet
    // fullScreenIntent auf Heads-up sobald entsperrt — das Overlay löst
    // das, weil es als SYSTEM_ALERT_WINDOW über alles gezeichnet wird).
    // No-op falls Berechtigung nicht erteilt.
    unawaited(IncomingCallOverlay.show(
      callId: callId,
      callerName: resolvedName,
      callerAvatar: avatarUrl,
      callType: callType,
      labelIncoming: 'chat.incomingCall'.tr(),
      labelAccept: 'chat.accept'.tr(),
      labelDecline: 'chat.decline'.tr(),
    ));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _postDeclineSub?.cancel();
    _teardownSubs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
