/// SKILL: mensaena-architektur
/// Provider fuer Shorebird-Patch-Status.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shorebird_patch_service.dart';

/// true wenn ein Shorebird-OTA-Patch heruntergeladen wurde und ein
/// App-Restart noetig ist um ihn zu aktivieren.
final shorebirdPatchAvailableProvider = FutureProvider<bool>((ref) async {
  return ShorebirdPatchService.checkForUpdate();
});

/// Nummer des aktuell installierten Patches (oder null).
/// Wird im Settings-Screen als Info-Zeile angezeigt.
final currentPatchNumberProvider = FutureProvider<int?>((ref) async {
  return ShorebirdPatchService.currentPatchNumber();
});
