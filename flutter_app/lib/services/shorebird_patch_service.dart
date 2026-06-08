/// SKILL: mensaena-architektur
/// ShorebirdPatchService — OTA-Patch Download + Ready-Detection.
///
/// Pendant zum Weltenbibliothek-Pattern. Wichtiger Unterschied zur vorherigen
/// Mensaena-Implementierung:
///   - Vorher: nur `checkForUpdate()` → liefert UpdateStatus.outdated wenn der
///     Shorebird-Server einen neuen Patch hat. Aber: der Patch wurde NIE
///     wirklich heruntergeladen. Resultat: User sah nie einen Restart-Banner.
///   - Jetzt: `checkAndDownloadPatch()` ruft `_shorebird.update()` auf wenn
///     outdated → echter Download. Danach feuert der Service ein Event auf
///     dem `onPatchReady` Broadcast-Stream, sobald `readNextPatch()` einen
///     pending Patch zeigt. UpdateGate hoert mit und zeigt den Restart-Banner.
///
/// Lifecycle:
///   - main.dart _initBackgroundServices → checkAndDownloadPatch() im Background
///   - UpdateGate.initState → Stream-Listener auf onPatchReady
///   - UpdateGate.didChangeAppLifecycleState(resumed) → re-trigger
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Ergebnis eines Patch-Ready-Checks.
class PatchCheckResult {
  const PatchCheckResult({
    this.patchReady = false,
    this.downloading = false,
    this.currentPatchNumber,
    this.nextPatchNumber,
  });

  /// true wenn ein Patch heruntergeladen ist und beim naechsten App-Start
  /// aktiv wird.
  final bool patchReady;

  /// true waehrend gerade ein Patch vom Shorebird-Server geladen wird
  /// (zwischen erkanntem `outdated` und Download-Ende). Erlaubt der UI
  /// einen "Update wird geladen…"-Hinweis BEVOR der Restart-Banner kommt.
  final bool downloading;

  /// Aktuell installierte Patch-Nummer (null bei kein Patch / Debug).
  final int? currentPatchNumber;

  /// Nummer des wartenden Patches (null wenn kein Patch wartet).
  final int? nextPatchNumber;

  static const empty = PatchCheckResult();
}

class ShorebirdPatchService {
  ShorebirdPatchService._();
  static final ShorebirdPatchService instance = ShorebirdPatchService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Stream der feuert sobald ein Patch heruntergeladen ist und beim
  /// naechsten Start aktiv wird. UpdateGate hoert hier zu und zeigt den
  /// Restart-Banner. Broadcast damit mehrere Widgets parallel zuhoeren
  /// koennen ohne sich gegenseitig zu blockieren.
  final StreamController<PatchCheckResult> _patchReadyController =
      StreamController<PatchCheckResult>.broadcast();

  Stream<PatchCheckResult> get onPatchReady => _patchReadyController.stream;

  /// Nummer des aktuell installierten Patches.
  /// null = kein Patch installiert ODER Debug-Build ohne Shorebird-Engine.
  Future<int?> currentPatchNumber() async {
    try {
      if (!_updater.isAvailable) return null;
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      if (kDebugMode) debugPrint('[Shorebird] readCurrentPatch failed: $e');
      return null;
    }
  }

  /// Prueft ohne Netzwerk-Call ob bereits ein heruntergeladener Patch
  /// wartet (z.B. weil Shorebird ihn beim letzten Start auto-downloaded
  /// hat aber wir noch nicht neugestartet haben).
  Future<PatchCheckResult> checkPatchReady() async {
    try {
      if (!_updater.isAvailable) return PatchCheckResult.empty;
      final current = await _updater.readCurrentPatch();
      final next = await _updater.readNextPatch();
      if (next == null) {
        return PatchCheckResult(currentPatchNumber: current?.number);
      }
      final ready = current == null || next.number != current.number;
      return PatchCheckResult(
        patchReady: ready,
        currentPatchNumber: current?.number,
        nextPatchNumber: next.number,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Shorebird] checkPatchReady failed: $e');
      return PatchCheckResult.empty;
    }
  }

  /// Fragt den Shorebird-Server aktiv nach einem neuen Patch und LAEDT ihn
  /// runter wenn outdated. Nach erfolgreichem Download feuert der Service
  /// ein Event auf [onPatchReady].
  ///
  /// Das war der Kern-Bug der vorherigen Implementierung: hier wurde nur
  /// `checkForUpdate()` aufgerufen ohne `update()` — daher wurde der Patch
  /// nie geladen und der Banner nie gezeigt.
  Future<void> checkAndDownloadPatch() async {
    try {
      if (!_updater.isAvailable) {
        if (kDebugMode) {
          debugPrint('[Shorebird] not available (debug build?) — skipping');
        }
        return;
      }
      // Vor dem Download: bereits ein Patch heruntergeladen? Dann sofort
      // den Stream feuern und nicht weitermachen.
      final pre = await checkPatchReady();
      if (pre.patchReady) {
        if (!_patchReadyController.isClosed) {
          _patchReadyController.add(pre);
        }
        return;
      }
      final status = await _updater.checkForUpdate();
      if (status != UpdateStatus.outdated) return;
      // Download startet jetzt → UI sofort "wird geladen…" zeigen, damit
      // der User sieht dass gerade ein Patch reinkommt (vorher war der
      // Download komplett unsichtbar bis er fertig war).
      if (!_patchReadyController.isClosed) {
        _patchReadyController.add(const PatchCheckResult(downloading: true));
      }
      await _updater.update();
      // Re-check: jetzt sollte readNextPatch != null sein.
      final post = await checkPatchReady();
      if (post.patchReady && !_patchReadyController.isClosed) {
        _patchReadyController.add(post);
      }
    } on UpdateException catch (e) {
      if (kDebugMode) debugPrint('[Shorebird] update failed: ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Shorebird] checkAndDownload failed: $e');
    }
  }

  void dispose() {
    _patchReadyController.close();
  }
}
