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
