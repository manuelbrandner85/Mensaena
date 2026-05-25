/// SKILL: mensaena-features
/// Global CallKit-Event-Bus.
///
/// Vorher: CallKit-Events (Accept/Decline/Timeout/Ended) wurden nur im
/// IncomingCallListener-Widget gehört. Das Widget mountet aber erst NACH
/// dem Auth-Flow / Dashboard-Mount. Bei Cold-Start (App war killed, User
/// tappt Accept auf der nativen CallKit-UI) gehen die Events verloren —
/// die App startet, landet im Dashboard, der Anruf ist weg.
///
/// Jetzt: `CallEventBus.init()` wird in `main.dart` VOR `runApp()`
/// aufgerufen. Damit ist der Listener aktiv bevor irgendein Widget
/// mountet. Accept-Events triggern DB-Update + Navigation via
/// rootNavigatorKey (mit Retry-Loop bis GoRouter ready ist).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:go_router/go_router.dart';

import '../config/routes/app_router.dart' show rootNavigatorKey;
import 'callkit_service.dart';
import 'dm_call_service.dart';
import 'supabase_service.dart';

class CallContext {
  const CallContext({
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

class CallEventBus {
  CallEventBus._();

  static StreamSubscription<CallEvent?>? _sub;
  static final Map<String, CallContext> _contexts = <String, CallContext>{};
  static final Set<String> _handledAccepts = <String>{};

  /// Muss in main.dart vor runApp() aufgerufen werden.
  static void init() {
    _sub ??= CallkitService.events().listen(_handle);
  }

  /// Widget-Layer ruft das wenn es eine eingehende Anruf-UI zeigt,
  /// damit beim Accept-Event Metadata fuer die Navigation vorliegt.
  static void recordContext(CallContext ctx) {
    _contexts[ctx.callId] = ctx;
  }

  /// Cold-Start-Recovery: liest aktive Plugin-Calls. Wenn einer schon
  /// im "accepted" State ist (User hat aus killed-State getappt),
  /// fuehrt Accept-Flow aus. Muss NACH GoRouter-Mount aufgerufen werden.
  static Future<void> recoverColdStart() async {
    try {
      final pending = await CallkitService.recoverPendingCall();
      if (pending == null) return;
      final callId = pending['id'] as String?;
      if (callId == null || callId.isEmpty) return;

      final extra = pending['extra'];
      final extraMap = (extra is Map)
          ? Map<String, dynamic>.from(extra)
          : <String, dynamic>{};
      final ctx = CallContext(
        callId: callId,
        roomName: (extraMap['room_name'] as String?) ?? '',
        callerName: (extraMap['caller_name'] as String?) ?? 'Nachbar:in',
        conversationId: extraMap['conversation_id'] as String?,
      );
      _contexts[callId] = ctx;

      final state = pending['state'] as String?;
      if (state == 'accepted' || state == 'connected') {
        await _onAccept(ctx);
      }
    } catch (e) {
      debugPrint('[CallEventBus] recoverColdStart failed: $e');
    }
  }

  static void _handle(CallEvent? event) {
    if (event == null) return;
    final body = event.body;
    if (body is! Map) return;

    String? callId = body['id'] as String?;
    final extra = body['extra'];
    Map<String, dynamic> extraMap = <String, dynamic>{};
    if (extra is Map) extraMap = Map<String, dynamic>.from(extra);
    callId ??= extraMap['id'] as String?;
    if (callId == null || callId.isEmpty) return;

    final ctx = _contexts[callId] ??
        CallContext(
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
      case Event.actionCallCallback:
        _onCallback(extraMap);
        break;
      default:
        break;
    }
  }

  /// Missed-Call-Callback: User tappt "Zurueckrufen" in der Missed-Call-
  /// Notification. Startet neuen Outgoing-Call an caller_id.
  static Future<void> _onCallback(Map<String, dynamic> extraMap) async {
    try {
      final callerId = extraMap['caller_id'] as String?;
      final conversationId = extraMap['conversation_id'] as String?;
      final callType = (extraMap['call_type'] as String?) ?? 'audio';
      if (callerId == null || conversationId == null) return;

      final result = await DmCallService.start(
        conversationId: conversationId,
        calleeId: callerId,
        callType: callType,
      );
      if (!result.success || result.callId == null) return;

      final peerName = (extraMap['caller_name'] as String?) ?? 'Nachbar:in';
      final route =
          '/dashboard/call/${result.callId}?room=${Uri.encodeComponent(result.roomName ?? '')}&peer=${Uri.encodeComponent(peerName)}';
      final nav = rootNavigatorKey.currentState;
      if (nav != null) {
        try {
          // ignore: use_build_context_synchronously
          nav.context.push(route);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CallEventBus] callback failed: $e');
    }
  }

  static Future<void> _onAccept(CallContext ctx) async {
    if (_handledAccepts.contains(ctx.callId)) return;
    _handledAccepts.add(ctx.callId);

    // Critical: status=active SOFORT setzen. Sonst hoert Caller ewig
    // Ringback. Vor Navigation — selbst wenn Navigation fehlschlaegt,
    // ist die Server-Seite konsistent.
    await _updateStatus(ctx.callId, 'active', answered: true);
    _contexts.remove(ctx.callId);

    final encName = Uri.encodeComponent(ctx.callerName);
    final encRoom = Uri.encodeComponent(ctx.roomName);
    final route =
        '/dashboard/call/${ctx.callId}?room=$encRoom&peer=$encName';

    final navState = rootNavigatorKey.currentState;
    if (navState != null) {
      try {
        // ignore: use_build_context_synchronously
        navState.context.push(route);
        return;
      } catch (_) {}
    }
    // Cold-Start-Retry: GoRouter braucht ein paar Frames bis ready.
    var tries = 0;
    Timer.periodic(const Duration(milliseconds: 100), (t) {
      tries++;
      final n = rootNavigatorKey.currentState;
      if (n != null) {
        try {
          n.context.push(route);
          t.cancel();
          return;
        } catch (_) {}
      }
      if (tries > 30) t.cancel(); // 3s max
    });
  }

  static Future<void> _onDecline(CallContext ctx) async {
    await _updateStatus(ctx.callId, 'cancelled');
    _contexts.remove(ctx.callId);
  }

  static Future<void> _onTimeout(CallContext ctx) async {
    await _updateStatus(ctx.callId, 'missed');
    _contexts.remove(ctx.callId);
  }

  static Future<void> _onEnded(CallContext ctx) async {
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
    _contexts.remove(ctx.callId);
  }

  static Future<void> _updateStatus(
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
}
