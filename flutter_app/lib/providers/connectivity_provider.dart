/// SKILL: mensaena-architektur
/// Zentraler Online/Offline-Status — ersetzt verstreute connectivity_plus-
/// Direktaufrufe. Basis für den globalen Offline-Banner (DashboardScaffold).
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = online (irgendeine Verbindung), false = offline. Startet optimistisch
/// mit `true`, bis der erste echte Connectivity-Check zurückkommt (verhindert
/// einen kurzen Offline-Blitz beim App-Start).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  try {
    yield isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* connectivity.onConnectivityChanged.map(isOnline);
});
