/// SKILL: mensaena-architektur
/// Provider fuer Shorebird-Patch-Status.
///
/// Wichtig: der "patch ready"-Provider hoert auf den Broadcast-Stream
/// `ShorebirdPatchService.onPatchReady`, statt selbst zu pollen. Dadurch
/// reagiert die UI sofort sobald `checkAndDownloadPatch()` in main.dart
/// einen Patch fertig heruntergeladen hat.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shorebird_patch_service.dart';

/// true wenn ein OTA-Patch heruntergeladen ist und beim naechsten
/// App-Start aktiv wird (Restart noetig).
///
/// Initial-Wert kommt aus `checkPatchReady()` (kein Netzwerk-Call —
/// schaut nur ins lokale Patch-Verzeichnis). Folge-Werte kommen ueber
/// den Broadcast-Stream sobald `checkAndDownloadPatch()` einen neuen
/// Patch heruntergeladen hat.
final shorebirdPatchAvailableProvider = StreamProvider<bool>((ref) async* {
  final initial = await ShorebirdPatchService.instance.checkPatchReady();
  yield initial.patchReady;
  await for (final ev in ShorebirdPatchService.instance.onPatchReady) {
    yield ev.patchReady;
  }
});

/// Nummer des aktuell aktiven Patches (Anzeige im Settings-Screen).
final currentPatchNumberProvider = FutureProvider<int?>((ref) async {
  return ShorebirdPatchService.instance.currentPatchNumber();
});
