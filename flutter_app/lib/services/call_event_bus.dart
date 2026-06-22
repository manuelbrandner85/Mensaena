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
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../config/routes/app_router.dart' show rootNavigatorKey;
import '../repositories/extra_repositories.dart';
import 'callkit_service.dart';
import 'dm_call_service.dart';
import 'incoming_call_overlay.dart';
import 'supabase_service.dart';

void _logDev(String msg) {
  if (kDebugMode) debugPrint(msg);
}

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
  // Post-Decline-Stream: feuert wenn User einen Anruf abgelehnt hat,
  // damit die UI ein Quick-Reply-Sheet zeigen kann ("Bin in 5 Min" etc).
  static final StreamController<CallContext> _postDeclineCtrl =
      StreamController<CallContext>.broadcast();

  static Stream<CallContext> get onPostDecline => _postDeclineCtrl.stream;

  /// Muss in main.dart vor runApp() aufgerufen werden.
  static void init() {
    _sub ??= CallkitService.events().listen(_handle);
  }

  /// Widget-Layer ruft das wenn es eine eingehende Anruf-UI zeigt,
  /// damit beim Accept-Event Metadata fuer die Navigation vorliegt.
  static void recordContext(CallContext ctx) {
    _contexts[ctx.callId] = ctx;
  }

  /// Cold-Start-Recovery: liest aktive Plugin-Calls UND die SecureStorage-
  /// Brücke des Overlay-Isolates. Wenn der User aus killed-State im Overlay
  /// auf Annehmen/Ablehnen getappt hat, lebt diese Aktion in
  /// `kOverlayPendingActionKey` und wird hier abgearbeitet. Muss NACH
  /// GoRouter-Mount aufgerufen werden.
  static Future<void> recoverColdStart() async {
    // 1. Overlay-Bridge zuerst (Samsung-Path) — schneller im Boot.
    await _recoverOverlayPending();

    // 2. CallKit-State (Lockscreen-Accept-Path).
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
      unawaited(ErrorLogsRepository.log(
        errorType: 'call_coldstart',
        message: 'recover callkit call=$callId state=$state '
            'room=${ctx.roomName.isEmpty ? "EMPTY" : "ok"}',
      ));
      if (state == 'accepted' || state == 'connected') {
        await _onAccept(ctx);
      }
    } catch (e) {
      _logDev('[CallEventBus] recoverColdStart failed: $e');
    }
  }

  /// Liest die SecureStorage-Brücke vom Overlay-Isolate. Format: 'action:callId'.
  /// Wird sofort gelöscht damit derselbe Eintrag nicht beim nächsten Start
  /// erneut feuert.
  static Future<void> _recoverOverlayPending() async {
    const storage = FlutterSecureStorage();
    String? raw;
    try {
      raw = await storage.read(key: 'mensaena_overlay_pending_action_v1');
      if (raw == null || raw.isEmpty) return;
      // Direkt löschen — egal ob erfolgreich abgearbeitet, sonst läuft die
      // Aktion bei jedem App-Start erneut.
      await storage.delete(key: 'mensaena_overlay_pending_action_v1');
    } catch (_) {
      return;
    }
    final colon = raw.indexOf(':');
    if (colon <= 0) return;
    final action = raw.substring(0, colon);
    final callId = raw.substring(colon + 1);
    if (callId.isEmpty) return;
    try {
      if (action == 'accept') {
        await acceptFromOverlay(callId);
      } else if (action == 'decline') {
        // Server-State setzen + CallKit-Notification beenden.
        unawaited(DmCallService.cancel(callId));
        unawaited(CallkitService.endCall(callId));
        _handledAccepts.add(callId);
      }
    } catch (e) {
      _logDev('[CallEventBus] _recoverOverlayPending failed: $e');
    }
  }

  /// Beim Logout: Dedupe-Sets clearen damit der naechste User
  /// nicht mit den callIds des vorherigen kollidiert.
  static void clearHandled() {
    _handledAccepts.clear();
    _contexts.clear();
  }

  /// Liest, ob ein Call schon angenommen wurde — vom IncomingCallListener
  /// genutzt, um Cold-Start-Doppel-Trigger zu unterdrücken (Realtime initial
  /// snapshot würde sonst die noch-nicht-auf-active-gesetzte Row erneut als
  /// "neuer ringing-Call" interpretieren).
  static bool isHandledAccept(String callId) =>
      _handledAccepts.contains(callId);

  /// Markiert einen Call extern als "bereits angenommen" — fürs Seeding
  /// aus CallKit.activeCalls() beim Cold-Start.
  static void recordHandledAccept(String callId) {
    _handledAccepts.add(callId);
  }

  /// Annahme aus dem System-Overlay (SYSTEM_ALERT_WINDOW) — entweder
  /// Main-Isolate war wach und der Listener fängt den Tap direkt, oder
  /// die App lebt nur im Overlay-Isolate; in beiden Fällen brauchen wir
  /// am Ende einen Call-Screen-Aufbau. Der Context wird ggf. aus der DB
  /// nachgeladen, falls _contexts den Eintrag noch nicht kennt.
  static Future<void> acceptFromOverlay(String callId) async {
    if (_handledAccepts.contains(callId)) {
      unawaited(ErrorLogsRepository.log(
        errorType: 'call_accept_dup',
        message: 'acceptFromOverlay blocked (already handled) call=$callId',
      ));
      return;
    }
    // CallKit-Notification (falls parallel aktiv) beenden.
    unawaited(CallkitService.endCall(callId));

    CallContext? ctx = _contexts[callId];
    if (ctx == null) {
      // Cold-Start-Path: Anrufer-Daten aus der DB ziehen.
      try {
        final row = await sb
            .from('dm_calls')
            .select('id, caller_id, conversation_id, room_name, call_type')
            .eq('id', callId)
            .maybeSingle();
        if (row == null) return;
        String callerName = 'Nachbar:in';
        try {
          final p = await sb
              .from('profiles')
              .select('display_name, name')
              .eq('id', row['caller_id'] as String)
              .maybeSingle();
          if (p != null) {
            callerName = (p['display_name'] as String?) ??
                (p['name'] as String?) ??
                callerName;
          }
        } catch (_) {/* ignore */}
        ctx = CallContext(
          callId: callId,
          roomName: (row['room_name'] as String?) ?? '',
          callerName: callerName,
          conversationId: row['conversation_id'] as String?,
        );
        _contexts[callId] = ctx;
      } catch (e) {
        _logDev('[CallEventBus] acceptFromOverlay context lookup failed: $e');
        return;
      }
    }
    await _onAccept(ctx);
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
  /// Notification. Validiert caller_id gegen DB-Row bevor neuer Call
  /// gestartet wird — verhindert Call-Spoofing via crafted FCM-Payload.
  static Future<void> _onCallback(Map<String, dynamic> extraMap) async {
    try {
      final callId = extraMap['id'] as String?;
      final claimedCallerId = extraMap['caller_id'] as String?;
      if (callId == null || claimedCallerId == null) return;

      // Security: caller_id aus FCM-extras MUSS mit DB-Row uebereinstimmen.
      // Sonst koennte Angreifer crafted Push schicken der Opfer dazu bringt
      // einen beliebigen User anzurufen.
      final row = await sb
          .from('dm_calls')
          .select('caller_id, conversation_id, call_type')
          .eq('id', callId)
          .maybeSingle();
      if (row == null) return;
      final dbCallerId = row['caller_id'] as String?;
      if (dbCallerId == null || dbCallerId != claimedCallerId) {
        _logDev('[CallEventBus] callback caller_id mismatch — rejected');
        return;
      }

      final conversationId = row['conversation_id'] as String?;
      final callType = (row['call_type'] as String?) ?? 'audio';
      if (conversationId == null) return;

      final result = await DmCallService.start(
        conversationId: conversationId,
        calleeId: dbCallerId,
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
      _logDev('[CallEventBus] callback failed: $e');
    }
  }

  /// Holt MainActivity in den Vordergrund (Android). Im CallKit-Accept-Pfad
  /// fehlte das bisher (nur der Overlay-Pfad tat es) → die Call-Route wurde
  /// zwar gepusht, war aber erst nach einem ZWEITEN Annehmen sichtbar
  /// („zweimal annehmen"-Bug). REORDER_TO_FRONT+SINGLE_TOP nutzt die
  /// bestehende Activity (kein State-Reset).
  static Future<void> _bringAppToForeground() async {
    if (!Platform.isAndroid) return;
    try {
      // ignore: prefer_const_constructors
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'de.mensaena.app',
        componentName: 'de.mensaena.app/.MainActivity',
        flags: const <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
          Flag.FLAG_ACTIVITY_SINGLE_TOP,
        ],
      );
      await intent.launch();
    } catch (_) {/* non-fatal */}
  }

  static Future<void> _onAccept(CallContext ctx) async {
    // Atomic check-and-add: Set.add() liefert false wenn schon vorhanden.
    // Verhindert Doppel-Accept-Race wenn User auf Lock-Screen zwei mal tappt.
    if (!_handledAccepts.add(ctx.callId)) {
      // Diagnose Kaltstart-„zweimal annehmen": erster Accept hat geblockt,
      // aber evtl. nicht navigiert/verbunden.
      unawaited(ErrorLogsRepository.log(
        errorType: 'call_accept_dup',
        message: 'onAccept blocked (already handled) call=${ctx.callId} '
            'room=${ctx.roomName.isEmpty ? "EMPTY" : "ok"}',
      ));
      return;
    }

    _contexts.remove(ctx.callId);

    // FIX „zweimal annehmen": App SOFORT in den Vordergrund holen, damit die
    // gleich gepushte Call-Route sichtbar wird (ohne zweites Tippen).
    unawaited(_bringAppToForeground());

    // System-Overlay (falls offen) sofort schließen, damit nicht parallel
    // zur Call-Screen-Animation noch das Vollbild-Ringen rendert.
    unawaited(IncomingCallOverlay.close());

    // SPEED: Status-Update + Navigation parallel. Vorher wurde 200-500ms
    // auf DB-Update gewartet bevor navigiert wird → User sah lange weiss.
    // Jetzt: Navigation startet sofort (Call-Screen kann sich aufbauen),
    // DB-Update laeuft fire-and-forget. Bei Fehler ist DB-State suboptimal
    // aber Call-Screen kann LiveKit trotzdem joinen.
    unawaited(_updateStatus(ctx.callId, 'active', answered: true));

    final encName = Uri.encodeComponent(ctx.callerName);
    final encRoom = Uri.encodeComponent(ctx.roomName);
    // accepted=1 → CallScreen verbindet direkt ohne Status-Query-Umweg.
    final route =
        '/dashboard/call/${ctx.callId}?room=$encRoom&peer=$encName&accepted=1';

    final navState = rootNavigatorKey.currentState;
    unawaited(ErrorLogsRepository.log(
      errorType: 'call_accept',
      message: 'onAccept call=${ctx.callId} navReady=${navState != null}',
    ));
    if (navState != null) {
      try {
        // ignore: use_build_context_synchronously
        navState.context.push(route);
        return;
      } catch (e) {
        unawaited(ErrorLogsRepository.log(
          errorType: 'call_accept_pusherr',
          message: 'immediate push failed: $e',
        ));
      }
    }
    // Cold-Start-Retry: GoRouter braucht teils mehrere Sekunden bis ready
    // (Flutter-Engine-Boot + Firebase-Init + Auth-Restore + Provider-Setup).
    // Vorher: 5s Deadline → User landete häufig NICHT im Call-Screen,
    // weil CallKit beim Annehmen aus dem Kill-State 6-8s braucht.
    // Jetzt: 30s Deadline + Pending-Route, die auch nach Boot ausgelöst wird.
    _pendingAcceptRoute = route;
    var tries = 0;
    Timer.periodic(const Duration(milliseconds: 80), (t) {
      tries++;
      final n = rootNavigatorKey.currentState;
      if (n != null) {
        try {
          n.context.push(route);
          _pendingAcceptRoute = null;
          t.cancel();
          unawaited(ErrorLogsRepository.log(
            errorType: 'call_accept',
            message: 'navigated after ${tries * 80}ms retry',
          ));
          return;
        } catch (_) {}
      }
      if (tries > 375) {
        t.cancel(); // 30s max
        unawaited(ErrorLogsRepository.log(
          errorType: 'call_accept_timeout',
          message: 'router not ready after 30s',
        ));
      }
    });
  }

  /// Wird vom Router beim ersten Build aufgerufen, damit ein während des
  /// Cold-Starts angenommener Call sofort den Call-Screen aufmacht (auch
  /// wenn der Timer-Retry noch nicht gegriffen hat).
  static String? consumePendingAcceptRoute() {
    final r = _pendingAcceptRoute;
    _pendingAcceptRoute = null;
    return r;
  }

  static String? _pendingAcceptRoute;

  static Future<void> _onDecline(CallContext ctx) async {
    unawaited(IncomingCallOverlay.close());
    await _updateStatus(ctx.callId, 'cancelled');
    _contexts.remove(ctx.callId);
    // UI-Schicht (IncomingCallListener) hoert hier und zeigt ein
    // Quick-Reply-Sheet damit der Anrufer eine kontextuelle Auto-Antwort
    // bekommt statt nur "verpasst".
    if (!_postDeclineCtrl.isClosed) {
      _postDeclineCtrl.add(ctx);
    }
  }

  static Future<void> _onTimeout(CallContext ctx) async {
    unawaited(IncomingCallOverlay.close());
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
