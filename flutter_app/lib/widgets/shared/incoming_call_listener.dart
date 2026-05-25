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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../services/call_event_bus.dart';
import '../../services/callkit_service.dart';
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
  // Deduplicate same call_id from Realtime + FCM (whoever wins first).
  final Set<String> _handledCallIds = <String>{};

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _authSub = sb.auth.onAuthStateChange.listen((_) {
      _teardownSubs();
      // Bei Login/Logout: handled-CallIds + global Bus-Dedupe clearen,
      // damit User A's gehandelte Calls nicht User B's gleiche IDs blocken.
      _handledCallIds.clear();
      CallEventBus.clearHandled();
      _setupListeners();
    });
  }

  void _setupListeners() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

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
        }
        continue;
      }
      if (status != 'ringing') continue;
      if (_handledCallIds.contains(id)) continue;
      // Ignore stale calls older than 60s.
      final createdAt =
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? now;
      if (now.difference(createdAt).inSeconds > 60) continue;
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
    if (id == null || _handledCallIds.contains(id)) return;
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
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _teardownSubs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
