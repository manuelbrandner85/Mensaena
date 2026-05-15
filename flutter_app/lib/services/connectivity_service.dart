import 'package:connectivity_plus/connectivity_plus.dart';

/// Kapselt connectivity_plus zu einem einfachen "online/offline" Bool-Stream.
/// UI watcht das, zeigt offline_screen wenn false.
class ConnectivityService {
  ConnectivityService();

  final Connectivity _c = Connectivity();

  Future<bool> isOnline() async {
    final results = await _c.checkConnectivity();
    return _isAnyConnected(results);
  }

  Stream<bool> watch() {
    return _c.onConnectivityChanged.map(_isAnyConnected).distinct();
  }

  bool _isAnyConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}

final connectivityService = ConnectivityService();
