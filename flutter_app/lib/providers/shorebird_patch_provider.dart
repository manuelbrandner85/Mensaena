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

/// Provider liefert das FULL Patch-Check-Result (inkl. nextPatchNumber)
/// statt nur bool, damit der Banner die Patch-Nummer kennt und beim
/// Wechsel zu einer neuen Nummer den dismissed-State zuruecksetzen kann.
///
/// Initial-Wert kommt aus `checkPatchReady()` (kein Netzwerk-Call —
/// schaut nur ins lokale Patch-Verzeichnis). Folge-Werte kommen ueber
/// den Broadcast-Stream sobald `checkAndDownloadPatch()` einen neuen
/// Patch heruntergeladen hat.
final shorebirdPatchCheckProvider =
    StreamProvider<PatchCheckResult>((ref) async* {
  final initial = await ShorebirdPatchService.instance.checkPatchReady();
  yield initial;
  await for (final ev in ShorebirdPatchService.instance.onPatchReady) {
    yield ev;
  }
});

/// Legacy-bool-Variante fuer den UpdateGate-Switch.
final shorebirdPatchAvailableProvider = Provider<bool>((ref) {
  return ref.watch(shorebirdPatchCheckProvider).value?.patchReady ?? false;
});

/// Nummer des aktuell aktiven Patches (Anzeige im Settings-Screen).
final currentPatchNumberProvider = FutureProvider<int?>((ref) async {
  return ShorebirdPatchService.instance.currentPatchNumber();
});
