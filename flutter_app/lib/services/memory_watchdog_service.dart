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

import '../repositories/extra_repositories.dart';

class MemoryWatchdogService {
  MemoryWatchdogService._();
  static final MemoryWatchdogService instance = MemoryWatchdogService._();

  Timer? _timer;
  bool _started = false;

  /// Weiche Schwelle: ab 80 % des konfigurierten Byte-Limits räumen wir den
  /// nicht-sichtbaren Cache-Anteil auf, bevor das harte Limit greift (das
  /// greift erst beim Decode des nächsten Bildes → kurzer Ruckler).
  static const double _softThreshold = 0.80;

  /// Telemetrie-Schwelle: ab 90 % melden wir nach error_logs, damit Admin
  /// sieht WO der Speicher knapp wird. Damit der Logger nicht spammt:
  /// frühestens alle 5 Min ein Event pro Session.
  static const double _telemetryThreshold = 0.90;
  static const Duration _telemetryCooldown = Duration(minutes: 5);
  DateTime? _lastTelemetryAt;
  String? _currentRoute;

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

  /// Letzte bekannte Route — wird vom GoRouter-Listener gesetzt, damit
  /// Telemetrie-Events sagen können WO der Speicher knapp wurde.
  /// Aufruf typischerweise aus `app_router.dart` redirect/observer.
  void updateRoute(String route) {
    _currentRoute = route;
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
    // Telemetrie: höhere Schwelle (90 %) — meldet an Admin, dass der Speicher
    // hier knapp wird. Mit Cooldown gegen Spam.
    if (ratio >= _telemetryThreshold) {
      _maybeReport(
        kind: 'soft_high',
        ratio: ratio,
        liveCount: cache.liveImageCount,
        pendingCount: cache.pendingImageCount,
      );
    }
  }

  void _maybeReport({
    required String kind,
    required double ratio,
    int? liveCount,
    int? pendingCount,
  }) {
    final now = DateTime.now();
    final last = _lastTelemetryAt;
    if (last != null && now.difference(last) < _telemetryCooldown) return;
    _lastTelemetryAt = now;
    final cache = PaintingBinding.instance.imageCache;
    final mb = (cache.currentSizeBytes / 1024 / 1024).toStringAsFixed(1);
    // Fire-and-forget — der Logger selbst fängt Fehler ab.
    unawaited(ErrorLogsRepository.log(
      errorType: 'memory_pressure',
      message: '[$kind] ratio=${(ratio * 100).toStringAsFixed(0)}% '
          'size=${mb}MB live=${liveCount ?? '?'} pending=${pendingCount ?? '?'} '
          'route=${_currentRoute ?? 'unknown'}',
    ));
  }

  /// OS meldet akuten Speichermangel → kompletter Cache-Reset.
  /// Aufruf aus `WidgetsBindingObserver.didHaveMemoryPressure`.
  void onMemoryPressure() {
    final cache = PaintingBinding.instance.imageCache;
    final ratioBefore = cache.maximumSizeBytes > 0
        ? cache.currentSizeBytes / cache.maximumSizeBytes
        : 0.0;
    cache.clear();
    cache.clearLiveImages();
    if (kDebugMode) {
      debugPrint('[MemoryWatchdog] OS-MemoryPressure → Cache komplett geleert');
    }
    // OS-MemoryPressure ist ALWAYS reportwürdig (ohne Cooldown). Das ist
    // ein echtes Warnsignal — der nächste Schritt ist OOM-Kill durch Android.
    _lastTelemetryAt = null;
    _maybeReport(
      kind: 'os_pressure',
      ratio: ratioBefore,
      liveCount: cache.liveImageCount,
      pendingCount: cache.pendingImageCount,
    );
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
