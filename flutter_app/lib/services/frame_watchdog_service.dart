/// SKILL: mensaena-design (Phase 6 — adaptives Qualitätssystem)
/// FrameWatchdog — misst echte Frame-Zeiten und drosselt das EffectsGate
/// zur Laufzeit, wenn das Gerät nicht hinterherkommt.
///
/// Mechanik:
///   - SchedulerBinding.addTimingsCallback liefert Build+Raster-Zeiten.
///   - Budget = 1 / Display-Refresh-Rate (60 Hz → 16,6 ms, 120 Hz → 8,3 ms),
///     plus 20 % Toleranz (vereinzelte Ausreißer sind normal).
///   - Rollierendes Fenster von 120 Frames: reißen > 10 % das Budget,
///     wird das EffectsProfile auf `reduced` GEDECKELT (nie auf none —
///     der Watchdog nimmt Schmuck weg, keine Funktion).
///   - Hysterese: Hochstufen erst nach 60 s ohne erneuten Trigger —
///     kein Flackern zwischen den Stufen.
///
/// Singleton nach dem Muster von MemoryWatchdogService; Start/Stop in
/// MensaenaApp. Der Cap fließt über [onCapChanged] in den
/// `runtimeEffectsCapProvider` (effects_gate_provider.dart).
library;

import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class FrameWatchdogService {
  FrameWatchdogService._();
  static final FrameWatchdogService instance = FrameWatchdogService._();

  static const int _windowSize = 120;
  static const double _jankRatioTrigger = 0.10;
  static const Duration _recoveryDelay = Duration(seconds: 60);

  void Function(bool capped)? onCapChanged;

  bool _running = false;
  bool _capped = false;
  int _framesSeen = 0;
  int _jankyFrames = 0;
  DateTime? _lastTrigger;
  TimingsCallback? _callback;

  void start({required void Function(bool capped) onCapChanged}) {
    if (_running) return;
    _running = true;
    this.onCapChanged = onCapChanged;
    _callback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
      _callback = null;
    }
    _resetWindow();
  }

  double get _budgetMs {
    // Display-Refresh-Rate des primären Views; Fallback 60 Hz.
    double rate = 60;
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) rate = views.first.display.refreshRate;
      if (rate < 30 || rate.isNaN) rate = 60;
    } catch (_) {}
    return (1000 / rate) * 1.2; // +20 % Toleranz
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_running) return;
    final budget = _budgetMs;
    for (final t in timings) {
      _framesSeen++;
      final ms = t.totalSpan.inMicroseconds / 1000;
      if (ms > budget) _jankyFrames++;
    }
    if (_framesSeen < _windowSize) {
      _maybeRecover();
      return;
    }
    final ratio = _jankyFrames / _framesSeen;
    if (ratio > _jankRatioTrigger) {
      _lastTrigger = DateTime.now();
      if (!_capped) {
        _capped = true;
        debugPrint('[FrameWatchdog] ${(ratio * 100).toStringAsFixed(0)}% '
            'janky frames -> Effekte auf reduced gedeckelt');
        onCapChanged?.call(true);
      }
    } else {
      _maybeRecover();
    }
    _resetWindow();
  }

  void _maybeRecover() {
    if (!_capped || _lastTrigger == null) return;
    if (DateTime.now().difference(_lastTrigger!) >= _recoveryDelay) {
      _capped = false;
      _lastTrigger = null;
      debugPrint('[FrameWatchdog] Frames stabil -> Effekt-Deckel aufgehoben');
      onCapChanged?.call(false);
    }
  }

  void _resetWindow() {
    _framesSeen = 0;
    _jankyFrames = 0;
  }
}
