/// SKILL: mensaena-features
/// Incoming-Call-Listener — Root-Wrapper Widget.
///
/// WhatsApp-Style: Statt eines Flutter-Dialogs zeigen wir die native
/// CallKit-Telecom-UI via `flutter_callkit_incoming`. Diese funktioniert
/// auch auf dem Lock-Screen und im App-Killed-State (FCM Background-
/// Handler triggert sie direkt). Hier im Foreground-Wrapper hoeren wir
/// auf 3 Quellen:
///
///   1. Supabase Realtime — Stream auf dm_calls.callee_id=me filtered
///      auf status='ringing'. Fires waehrend App offen ist.
///   2. FCM onMessage — Foreground data-only push (Race-Sicherung).
///   3. CallkitService.events() — User-Aktionen (Accept/Decline/Timeout)
///      werden von der nativen UI gemeldet → dm_calls.status updaten +
///      Navigation triggern.
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../config/routes/app_router.dart' show rootNavigatorKey;
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
  StreamSubscription<CallEvent?>? _callkitSub;
  // Deduplicate same call_id from Realtime + FCM (whoever wins first).
  final Set<String> _handledCallIds = <String>{};
  // Map callId → metadata fuer Navigation nach Accept (CallkitEvent traegt
  // nur die `extra`-Map die wir bei showIncoming mitgegeben haben).
  final Map<String, _CallContext> _callContexts = <String, _CallContext>{};

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _setupCallkitListener();
    // Cold-Start-Recovery: wenn User die App via CallKit-Accept aus dem
    // Killed-State gestartet hat, hat das Accept-Event vor Listener-Mount
    // gefeuert. Wir holen den aktiven Call ueber das Plugin und triggern
    // die Navigation manuell, sobald GoRouter ready ist.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverColdStart());
    // Re-subscribe whenever auth state changes (login/logout).
    _authSub = sb.auth.onAuthStateChange.listen((_) {
      _teardownSubs();
      _setupListeners();
    });
  }

  Future<void> _recoverColdStart() async {
    if (!mounted) return;
    final pending = await CallkitService.recoverPendingCall();
    if (pending == null || !mounted) return;
    final callId = pending['id'] as String?;
    if (callId == null) return;
    final extra = pending['extra'];
    final extraMap = (extra is Map)
        ? Map<String, dynamic>.from(extra)
        : <String, dynamic>{};
    final ctx = _CallContext(
      callId: callId,
      roomName: (extraMap['room_name'] as String?) ?? '',
      callerName: (extraMap['caller_name'] as String?) ?? 'Nachbar:in',
      conversationId: extraMap['conversation_id'] as String?,
    );
    _callContexts[callId] = ctx;
    // Wenn der Call schon "accepted" ist (User hat schon getappt),
    // direkt navigieren. Sonst ist es noch ringing und der Event-Stream
    // uebernimmt den Rest.
    final state = pending['state'] as String?;
    if (state == 'accepted' || state == 'connected') {
      await _onAccept(ctx);
    }
  }

  void _setupListeners() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    // 1. Supabase Realtime — primary source while online + app open.
    // Mit onError + cancelOnError:false damit Timeouts/Network-Drops die
    // App nicht crashen (RealtimeSubscribeException war vorher uncaught).
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

    // 2. FCM Foreground — secondary source (faster on cold-start race).
    try {
      _fcmSub = FirebaseMessaging.onMessage.listen(
        _handleFcmMessage,
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {/* fail-open */}
  }

  void _setupCallkitListener() {
    try {
      _callkitSub = CallkitService.events().listen(_handleCallkitEvent);
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
    // Profil ggf. nachladen wenn Name/Avatar nicht vom Push kommen.
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

    _callContexts[callId] = _CallContext(
      callId: callId,
      roomName: roomName,
      callerName: resolvedName,
      conversationId: conversationId,
    );

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
      // Falls CallKit fehlschlaegt — z.B. fehlende Permission — entfernen
      // wir aus _handledCallIds, damit das System es spaeter neu versuchen
      // kann (z.B. ueber FCM-Background-Handler).
      _handledCallIds.remove(callId);
    }
  }

  void _handleCallkitEvent(CallEvent? event) {
    if (event == null) return;
    final body = event.body;
    if (body is! Map) return;
    // Plugin liefert id direkt oder in extra.
    String? callId = body['id'] as String?;
    final extra = body['extra'];
    Map<String, dynamic> extraMap = <String, dynamic>{};
    if (extra is Map) {
      extraMap = Map<String, dynamic>.from(extra);
    }
    callId ??= extraMap['id'] as String?;
    if (callId == null || callId.isEmpty) return;

    final ctx = _callContexts[callId] ??
        _CallContext(
          callId: callId,
          roomName: (extraMap['room_name'] as String?) ?? '',
          callerName: (extraMap['caller_name'] as String?) ?? 'Nachbar:in',
          conversationId: extraMap['conversation_id'] as String?,
        );

    switch (event.event) {
      case Event.actionCallAccept:
        _onAccept(ctx);
        break;
      case Event.actionCallDecline:
        _onDecline(ctx);
        break;
      case Event.actionCallTimeout:
        _onTimeout(ctx);
        break;
      case Event.actionCallEnded:
        _onEnded(ctx);
        break;
      default:
        break;
    }
  }

  Future<void> _onAccept(_CallContext ctx) async {
    await _updateStatus(ctx.callId, 'active', answered: true);
    _callContexts.remove(ctx.callId);
    final encName = Uri.encodeComponent(ctx.callerName);
    final encRoom = Uri.encodeComponent(ctx.roomName);
    final route =
        '/dashboard/call/${ctx.callId}?room=$encRoom&peer=$encName';
    // Cold-Start-festes Routing via rootNavigatorKey statt context.push:
    // - Warm-Start: GoRouter ist bereits ready → push klappt sofort.
    // - Cold-Start: GoRouter braucht noch ein paar Frames → wir warten
    //   bis der NavigatorState mounted ist + retryen alle 100 ms.
    final navState = rootNavigatorKey.currentState;
    if (navState != null) {
      try {
        // ignore: use_build_context_synchronously
        navState.context.push(route);
        return;
      } catch (_) {}
    }
    // Retry-Loop bis 3 s — sichert Cold-Start-Navigation ab.
    var tries = 0;
    Timer.periodic(const Duration(milliseconds: 100), (t) {
      final n = rootNavigatorKey.currentState;
      tries++;
      if (n != null) {
        try {
          n.context.push(route);
          t.cancel();
          return;
        } catch (_) {}
      }
      if (tries > 30) t.cancel();
    });
  }

  Future<void> _onDecline(_CallContext ctx) async {
    await _updateStatus(ctx.callId, 'cancelled');
    _callContexts.remove(ctx.callId);
  }

  Future<void> _onTimeout(_CallContext ctx) async {
    await _updateStatus(ctx.callId, 'missed');
    _callContexts.remove(ctx.callId);
  }

  Future<void> _onEnded(_CallContext ctx) async {
    // Nur Status setzen wenn aktuell noch klingelt oder aktiv — sonst
    // ueberschreiben wir ggf. einen schon korrekten 'cancelled'.
    try {
      final r = await sb
          .from('dm_calls')
          .select('status')
          .eq('id', ctx.callId)
          .maybeSingle();
      final s = r?['status'] as String?;
      if (s == 'ringing' || s == 'active') {
        await _updateStatus(ctx.callId, 'ended');
      }
    } catch (_) {}
    _callContexts.remove(ctx.callId);
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
    } catch (_) {/* fail-open */}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _callkitSub?.cancel();
    _teardownSubs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CallContext {
  const _CallContext({
    required this.callId,
    required this.roomName,
    required this.callerName,
    this.conversationId,
  });

  final String callId;
  final String roomName;
  final String callerName;
  final String? conversationId;
}
