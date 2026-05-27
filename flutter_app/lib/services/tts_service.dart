/// SKILL: mensaena-features (Phase 12 F52)
/// Vorlesefunktion — Wrapper über flutter_tts mit Locale-Sync.
/// Status (isSpeaking) wird per Stream nach außen exposed damit UI
/// den Play/Stop-Button toggeln kann.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final _stateController = StreamController<bool>.broadcast();
  bool _initialized = false;
  bool _isSpeaking = false;

  Stream<bool> get isSpeakingStream => _stateController.stream;
  bool get isSpeaking => _isSpeaking;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.5); // Etwas langsamer für bessere Verständlichkeit.
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _stateController.add(true);
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _stateController.add(false);
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _stateController.add(false);
      });
      _tts.setErrorHandler((msg) {
        if (kDebugMode) debugPrint('[TTS] error: $msg');
        _isSpeaking = false;
        _stateController.add(false);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] init failed: $e');
    }
  }

  Future<void> speak(String text, {String? langCode}) async {
    await _ensureInit();
    if (text.trim().isEmpty) return;
    try {
      if (langCode != null) {
        await _tts.setLanguage(langCode);
      }
      await stop(); // immer erst stoppen damit kein Overlap.
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] speak failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    await _ensureInit();
    await _tts.setSpeechRate(rate.clamp(0.1, 1.5));
  }
}
