/// SKILL: mensaena-features (ZUSATZ-3 PiP)
/// Picture-in-Picture-Wrapper über Android-Native-Channel.
/// Aktuell nur Android (System-PiP via Activity.enterPictureInPictureMode).
/// iOS folgt sobald AVPictureInPictureController integriert ist.
///
/// Verwendung:
///   - PipService.enterPip(width: 16, height: 9) — manuell triggern
///   - PipService.isSupported() — vor PiP-Button-Render check
///   - PipService.inPipStream — UI kann Controls verstecken bei aktivem PiP
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('de.mensaena.app/pip');

  final StreamController<bool> _inPipController =
      StreamController<bool>.broadcast();
  bool _inPip = false;
  bool _initialized = false;

  /// `true` solange das System-PiP-Fenster sichtbar ist.
  bool get inPip => _inPip;

  /// Stream der PiP-Mode-Wechsel — UI hört darauf und versteckt
  /// Buttons/Controls im PiP-Modus.
  Stream<bool> get inPipStream => _inPipController.stream;

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final next = (call.arguments as Map?)?['inPip'] as bool? ?? false;
        _inPip = next;
        _inPipController.add(next);
      }
    });
  }

  /// `true` wenn das Gerät System-PiP unterstützt (Android 8+).
  /// iOS gibt aktuell immer `false` zurück bis AVPictureInPictureController
  /// integriert ist.
  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      instance._ensureInit();
      final r = await _channel.invokeMethod<bool>('isPipSupported');
      return r ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[PipService] isSupported failed: $e');
      return false;
    }
  }

  /// Bittet die System-Activity in den PiP-Modus zu wechseln.
  /// Aspect-Ratio wird als Rational(width,height) übergeben.
  /// Returns `true` wenn Android den Wechsel akzeptiert hat.
  static Future<bool> enterPip({int width = 16, int height = 9}) async {
    if (!Platform.isAndroid) return false;
    try {
      instance._ensureInit();
      final r = await _channel.invokeMethod<bool>(
        'enterPip',
        {'width': width, 'height': height},
      );
      return r ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[PipService] enterPip failed: $e');
      return false;
    }
  }
}
