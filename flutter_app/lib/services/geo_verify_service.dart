import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import 'location_service.dart';

/// SKILL: mensaena-architektur
/// Geo-Verifizierung: prueft ob aktuelle Position innerhalb von
/// AppConfig.geoVerifyToleranceMeters (default 2000m) eines Ziels liegt.
/// Wird z.B. fuer "Standort verifizieren" auf Profilen genutzt.
class GeoVerifyService {
  const GeoVerifyService._();

  /// Returns true wenn aktuelle Position ≤ Toleranz vom Target liegt.
  /// Wirft bei verweigerter Permission / deaktiviertem Service.
  static Future<({bool ok, double distanceMeters})> verify({
    required double targetLat,
    required double targetLng,
  }) async {
    final pos = await LocationService.getCurrentPosition(
      accuracy: LocationAccuracy.high,
    );
    final meters = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      targetLat,
      targetLng,
    );
    return (
      ok: meters <= AppConfig.geoVerifyToleranceMeters,
      distanceMeters: meters,
    );
  }
}
