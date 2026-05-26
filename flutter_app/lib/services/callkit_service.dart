import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// SKILL: mensaena-features
/// Native CallKit-Bridge: zeigt eine echte System-Call-UI (Vollbild,
/// klingelnd, mit Annehmen/Ablehnen-Buttons) — auch wenn die App
/// geschlossen oder das Telefon gesperrt ist (WhatsApp-Style).
///
/// Verwendet das Plugin `flutter_callkit_incoming`. Android zeigt die
/// Telecom-CallScreen (ConnectionService), iOS waere CallKit native.
/// Mensaena ist aktuell Android-only — iOS-Config liegt vor zur
/// spaeteren Aktivierung.
///
/// Architektur:
///   - `firebaseBackgroundMessageHandler` (push_notification_service.dart)
///     ruft bei `type == 'incoming_call'` → `showIncoming(...)`.
///   - `IncomingCallListener` (Foreground + Realtime) ruft ebenfalls
///     `showIncoming(...)` und horcht auf `events()` fuer User-Aktionen.
class CallkitService {
  const CallkitService._();

  /// Plugin-Initialisierung. Wichtig: NICHT endAllCalls() hier, sonst
  /// werden Cold-Start-Calls (User tappt CallKit-Accept aus geschlossener
  /// App heraus) abgewuergt BEVOR der Listener das Accept-Event sieht.
  /// Cleanup laufender Calls passiert nur explizit beim Logout via
  /// [endAllCalls].
  static Future<void> initialize() async {
    // No-op stub. Plugin braucht keine explizite init().
  }

  /// Bei Cold-Start (App via CallKit-Accept aus killed-State gestartet):
  /// queries active calls vom Plugin. Wenn einer existiert, liefert
  /// die call_id zurueck damit der Caller das Navigations-Intent setzen kann.
  static Future<Map<String, dynamic>?> recoverPendingCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final first = calls.first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
    } catch (e) {
      debugPrint('[CallkitService] recoverPendingCall failed: $e');
    }
    return null;
  }

  /// Zeigt die native eingehende Anruf-UI.
  /// [callType] = 'audio' oder 'video'.
  static Future<void> showIncoming({
    required String callId,
    required String callerName,
    String? callerAvatar,
    String? roomName,
    String? conversationId,
    String? callerId,
    String callType = 'audio',
  }) async {
    try {
      final type = callType == 'video' ? 1 : 0;
      final params = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'Mensaena',
        avatar: callerAvatar,
        handle: callerName,
        type: type,
        duration: 45000, // 45s Ringing-Timeout
        textAccept: _tr('chat.accept', 'Annehmen'),
        textDecline: _tr('chat.decline', 'Ablehnen'),
        missedCallNotification: NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: _tr('call.callMissed', 'Nicht erreicht'),
          callbackText: _tr('call.callBack', 'Zurückrufen'),
        ),
        // Extra-Felder werden beim Accept-Event mitgeliefert
        // → Deep-Link Navigation kann darauf zugreifen.
        extra: <String, dynamic>{
          if (roomName != null) 'room_name': roomName,
          if (conversationId != null) 'conversation_id': conversationId,
          if (callerId != null) 'caller_id': callerId,
          'caller_name': callerName,
          'call_type': callType,
        },
        android: const AndroidParams(
          // FIX: isCustomNotification=false → Android's native Full-Screen-
          // Intent-Notification (wie Telefon-App). Vorher (true) musste der
          // User die Heads-Up-Notification erst tappen + dann nochmal auf
          // Annehmen — jetzt direkt Vollbild-Call-UI mit Accept/Decline-
          // Wischen wie bei einem normalen Anruf.
          isCustomNotification: false,
          isShowLogo: true,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0A0F1C',
          actionColor: '#1EAAA6',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Eingehende Anrufe',
          missedCallNotificationChannelName: 'Verpasste Anrufe',
          isShowFullLockedScreen: true,
          isShowCallID: false,
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('[CallkitService] showIncoming failed: $e');
      rethrow;
    }
  }

  /// Stream der CallKit-Events (Accept/Decline/Timeout/Ended).
  static Stream<CallEvent?> events() => FlutterCallkitIncoming.onEvent;

  /// Beendet einen einzelnen Call (z.B. wenn Anrufer cancelt).
  static Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallkitService] endCall failed: $e');
    }
  }

  /// Beendet ALLE laufenden Calls (z.B. beim Logout).
  static Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallkitService] endAllCalls failed: $e');
    }
  }

  /// Liest den letzten aktiven Call (z.B. nach Cold-Start nach Accept).
  /// Returns null wenn kein aktiver Call vorliegt.
  static Future<dynamic> activeCalls() async {
    try {
      return await FlutterCallkitIncoming.activeCalls();
    } catch (_) {
      return null;
    }
  }

  // i18n-Helper mit Fallback (Background-Isolate hat ggf. kein EasyLoc).
  static String _tr(String key, String fallback) {
    try {
      final v = tr(key);
      return v == key ? fallback : v;
    } catch (_) {
      return fallback;
    }
  }
}
