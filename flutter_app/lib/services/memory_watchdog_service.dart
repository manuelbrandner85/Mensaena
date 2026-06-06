/// SKILL: mensaena-architektur — Speicher-Wächter (OOM-Prävention).
///
/// Hintergrund: User-Report "App wird mit der Zeit langsam und stürzt ab".
/// Ursache ist der über Stunden anwachsende Image-Decoder-Cache plus
/// Bitmaps, die zwar evictet werden könnten, aber zwischen den GC-Zyklen
/// liegen bleiben. Flutter deckelt den Cache hart (siehe main.dart:
/// maximumSize / maximumSizeBytes), aber er räumt ihn NIE proaktiv auf,
/// solange das Limit nicht erreicht ist — auf RAM-schwachen Geräten ist
/// das Limit aber schon zu viel.
///
/// Dieser Service ist die zweite Verteidigungslinie:
///   1. Periodischer Soft-Check (alle 60 s): liegt der ImageCache über einer
///      weichen Schwelle, wird der "lebende" Teil (gerade nicht sichtbar)
///      geleert — sichtbare Bilder bleiben, kein Flackern.
///   2. OS-Memory-Pressure (`didHaveMemoryPressure`): Vollständiges Leeren —
///      Android hat akut zu wenig RAM, jedes Byte zählt.
///   3. App in den Hintergrund (`paused`): "Live"-Bilder freigeben, weil der
///      User sie ohnehin nicht sieht — andere Apps bekommen den RAM.
///
/// Einmalige globale Initialisierung über [start]/[stop] aus MensaenaApp.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class MemoryWatchdogService {
  MemoryWatchdogService._();
  static final MemoryWatchdogService instance = MemoryWatchdogService._();

  Timer? _timer;
  bool _started = false;

  /// Weiche Schwelle: ab 80 % des konfigurierten Byte-Limits räumen wir den
  /// nicht-sichtbaren Cache-Anteil auf, bevor das harte Limit greift (das
  /// greift erst beim Decode des nächsten Bildes → kurzer Ruckler).
  static const double _softThreshold = 0.80;

  /// Startet den periodischen Soft-Check. Idempotent — mehrfacher Aufruf
  /// (z. B. Hot-Reload) legt keinen zweiten Timer an.
  void start({Duration interval = const Duration(seconds: 60)}) {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(interval, (_) => _softCheck());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Soft-Check: Nur den "lebenden" (nicht sichtbar gehaltenen) Cache-Anteil
  /// leeren, wenn er über der weichen Schwelle liegt. Sichtbare Bilder
  /// bleiben → kein Flackern in der UI.
  void _softCheck() {
    final cache = PaintingBinding.instance.imageCache;
    final maxBytes = cache.maximumSizeBytes;
    if (maxBytes <= 0) return;
    final ratio = cache.currentSizeBytes / maxBytes;
    if (ratio >= _softThreshold) {
      // clearLiveImages() gibt die ImageStreamCompleter frei, die nur noch
      // referenziert sind, weil das Bild kürzlich sichtbar war — nicht die
      // gerade aktiv gemalten. evict des LRU-Tails passiert dadurch zügiger.
      cache.clearLiveImages();
      if (kDebugMode) {
        debugPrint(
          '[MemoryWatchdog] Soft-Evict bei ${(ratio * 100).toStringAsFixed(0)}% '
          '(${(cache.currentSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)',
        );
      }
    }
  }

  /// OS meldet akuten Speichermangel → kompletter Cache-Reset.
  /// Aufruf aus `WidgetsBindingObserver.didHaveMemoryPressure`.
  void onMemoryPressure() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    if (kDebugMode) {
      debugPrint('[MemoryWatchdog] OS-MemoryPressure → Cache komplett geleert');
    }
  }

  /// App geht in den Hintergrund → "lebende" Bilder freigeben (der User
  /// sieht sie nicht). Beim Zurückkehren werden sie bei Bedarf neu decodiert.
  /// Aufruf aus `didChangeAppLifecycleState(paused)`.
  void onAppPaused() {
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Manuelles "Cache leeren" aus den Einstellungen — Volltreffer-Reset.
  /// Gibt die freigegebene Größe in MB zurück (für UI-Feedback).
  double clearAll() {
    final cache = PaintingBinding.instance.imageCache;
    final freedMb = cache.currentSizeBytes / 1024 / 1024;
    cache.clear();
    cache.clearLiveImages();
    return freedMb;
  }
}
