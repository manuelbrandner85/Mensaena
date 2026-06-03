/// SKILL: mensaena-features
/// Controller-Schicht für das Vollbild-Anruf-Overlay (SYSTEM_ALERT_WINDOW).
/// Diese Datei läuft im Main-Isolate UND im FCM-Background-Isolate — beide
/// rufen `IncomingCallOverlay.show(...)` mit den Anrufer-Daten auf. Das
/// Overlay-Isolate rendert die UI; Annehmen/Ablehnen-Taps kommen via
/// shareData zurück und werden hier in CallEventBus-Aufrufe übersetzt.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'call_event_bus.dart';
import 'callkit_service.dart';
import 'dm_call_service.dart';

class IncomingCallOverlay {
  IncomingCallOverlay._();

  static StreamSubscription<dynamic>? _sub;
  static bool _listenerAttached = false;

  /// Vom Main-Isolate beim App-Start aufrufen, damit Aktionen aus dem
  /// Overlay (Annehmen/Ablehnen) abgefangen und an CallEventBus weitergeleitet
  /// werden, sobald sie eintreffen.
  static void attachActionListener() {
    if (_listenerAttached) return;
    _listenerAttached = true;
    try {
      _sub = FlutterOverlayWindow.overlayListener.listen(_handleAction);
    } catch (e) {
      debugPrint('[IncomingCallOverlay] listener attach failed: $e');
    }
  }

  /// Räumt den Listener auf (z. B. beim Logout).
  static Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _listenerAttached = false;
  }

  static Future<void> _handleAction(dynamic raw) async {
    if (raw is! Map) return;
    if (raw['type'] != 'overlay_action') return;
    final action = raw['action'] as String?;
    final callId = raw['callId'] as String?;
    if (callId == null || callId.isEmpty) return;
    if (action == 'accept') {
      await CallEventBus.acceptFromOverlay(callId);
    } else if (action == 'decline') {
      // Server-seitig als 'cancelled' markieren (gleiches Verhalten wie
      // CallKit-Decline).
      try {
        await DmCallService.cancel(callId);
      } catch (_) {/* non-fatal */}
      // CallKit-Notification falls noch aktiv mit beenden.
      unawaited(CallkitService.endCall(callId));
    }
  }

  /// Öffnet das Vollbild-Overlay über jeder App / dem Sperrbildschirm.
  /// Wenn SYSTEM_ALERT_WINDOW nicht erteilt ist → still ein No-Op.
  /// Wenn Overlay schon offen ist → erst schließen, dann neu öffnen.
  static Future<void> show({
    required String callId,
    required String callerName,
    String? callerAvatar,
    String callType = 'audio',
    // Lokalisierte Labels (Overlay-Isolate hat kein easy_localization).
    String labelIncoming = 'Eingehender Anruf',
    String labelAccept = 'Annehmen',
    String labelDecline = 'Ablehnen',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted != true) return;
      if ((await FlutterOverlayWindow.isActive()) == true) {
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
      }
      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.fullCover,
        width: WindowSize.matchParent,
        enableDrag: false,
        // Über Lockscreen UND System-Bars — das ist der ganze Sinn.
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        overlayTitle: labelIncoming,
        overlayContent: callerName,
      );
      // Kleines Delay, damit das Overlay-Isolate die Initial-Frame-Pipeline
      // gebootet hat und unseren Listener auf overlayListener aufgesetzt hat.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await FlutterOverlayWindow.shareData(<String, dynamic>{
        'type': 'incoming',
        'callId': callId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'callType': callType,
        'labelIncoming': labelIncoming,
        'labelAccept': labelAccept,
        'labelDecline': labelDecline,
      });
    } catch (e) {
      debugPrint('[IncomingCallOverlay] show failed: $e');
    }
  }

  /// Schließt das Overlay (z. B. nach Annehmen, Ablehnen, Timeout, Ended).
  static Future<void> close() async {
    if (!Platform.isAndroid) return;
    try {
      if ((await FlutterOverlayWindow.isActive()) == true) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {/* non-fatal */}
  }
}
