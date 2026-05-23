import 'location_service.dart';

/// SKILL: mensaena-features
/// Profil-Sichtbarkeit + Nachbar-/Trusted-Check.
///
/// profile_visibility:
/// - public:    Alle sehen alles (modulo show_* Toggles).
/// - neighbors: Nur User innerhalb radius_km sehen Details.
/// - private:   Nur Name + Avatar sichtbar.
class PrivacyService {
  const PrivacyService._();

  /// Darf Viewer das Profil sehen?
  static bool canSeeProfile({
    required String visibility,
    required String viewerId,
    required String ownerId,
    bool isNeighbor = false,
    bool isTrusted = false,
  }) {
    if (viewerId == ownerId) return true;
    switch (visibility) {
      case 'public':
        return true;
      case 'neighbors':
        return isNeighbor || isTrusted;
      case 'private':
        return false;
      default:
        return true;
    }
  }

  /// Darf Viewer dem User eine Nachricht schreiben?
  static bool canMessage({
    required String allowMessagesFrom,
    required String viewerId,
    required String ownerId,
    bool isTrusted = false,
  }) {
    if (viewerId == ownerId) return false;
    switch (allowMessagesFrom) {
      case 'everyone':
        return true;
      case 'trusted':
        return isTrusted;
      case 'nobody':
        return false;
      default:
        return true;
    }
  }

  /// Pruefung Nachbar-Status via Haversine ≤ radius_km.
  static bool isNeighbor({
    required double viewerLat,
    required double viewerLng,
    required double ownerLat,
    required double ownerLng,
    required int ownerRadiusKm,
  }) {
    final distKm = LocationService.haversineKm(
      viewerLat,
      viewerLng,
      ownerLat,
      ownerLng,
    );
    return distKm <= ownerRadiusKm.toDouble();
  }

  /// Show-Toggle anwenden — gibt den Wert nur zurueck wenn der Toggle erlaubt.
  static T? maybeShow<T>(T? value, {required bool show}) => show ? value : null;
}
