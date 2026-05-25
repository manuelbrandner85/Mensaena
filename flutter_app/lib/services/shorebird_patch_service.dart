/// SKILL: mensaena-architektur
/// ShorebirdPatchService — Wrapper um ShorebirdUpdater fuer OTA-Patches.
///
/// Shorebird laedt Patches automatisch im Hintergrund. Damit sie aktiv
/// werden, muss die App neugestartet werden. Dieses Service liefert
/// die Info ob ein Restart noetig ist und welcher Patch aktuell aktiv ist.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdPatchService {
  ShorebirdPatchService._();
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Nummer des aktuell installierten Patches (null = kein Patch /
  /// Debug-Build ohne Shorebird-Engine).
  static Future<int?> currentPatchNumber() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[Shorebird] readCurrentPatch failed: $e');
      return null;
    }
  }

  /// true wenn ein neuer Patch verfuegbar ist (Download passiert
  /// automatisch durch Shorebird; Restart noetig um zu aktivieren).
  static Future<bool> checkForUpdate() async {
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      debugPrint('[Shorebird] checkForUpdate failed: $e');
      return false;
    }
  }
}
