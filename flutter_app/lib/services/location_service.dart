import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// SKILL: mensaena-architektur
/// GPS + Distanzen. Haversine-Distanz für Nachbarschafts-Check.
class LocationService {
  const LocationService._();

  /// Aktuelle Position holen. Wirft bei verweigerter Permission oder
  /// deaktiviertem Service.
  static Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _LocationError('Standort-Dienste deaktiviert.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const _LocationError('Standort-Berechtigung verweigert.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationError(
        'Standort dauerhaft verweigert — in den Einstellungen aktivieren.',
      );
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
      timeLimit: timeLimit,
    );
  }

  /// Robuste Positionsermittlung für die Karte: versucht einen frischen
  /// Fix (großzügiger Timeout), fällt bei Timeout/Fehler auf die letzte
  /// bekannte Position zurück, statt komplett zu scheitern. Liefert null
  /// nur wenn wirklich gar nichts verfügbar ist (kein Wurf → kein stilles
  /// Verschlucken mehr beim Aufrufer).
  static Future<Position?> getBestPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Geolocator.getLastKnownPosition();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return Geolocator.getLastKnownPosition();
      }
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: const Duration(seconds: 18),
        );
      } catch (_) {
        // Timeout / kein Fix → letzte bekannte Position als Fallback.
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Haversine-Distanz zwischen zwei Koordinaten in Kilometern.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }
}

class _LocationError implements Exception {
  const _LocationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Provider fuer Single-Position-Fetch.
final currentPositionProvider = FutureProvider<Position>((ref) {
  return LocationService.getCurrentPosition();
});
