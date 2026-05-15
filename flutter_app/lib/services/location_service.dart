import 'package:geolocator/geolocator.dart';

/// Standort-Service: kapselt Permission-Flow und Position-Abruf.
/// UI ruft `requestPermissionAndFetch()` — handelt Denial gracefully.
class LocationService {
  const LocationService();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<Position?> requestPermissionAndFetch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!await isServiceEnabled()) return null;

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
    } catch (_) {
      // Timeout / Sensor unavailable — UI faellt auf letzter bekannter Position zurueck.
      return await Geolocator.getLastKnownPosition();
    }
  }

  Stream<Position> watchPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    int distanceFilterMeters = 25,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }
}

const locationService = LocationService();
