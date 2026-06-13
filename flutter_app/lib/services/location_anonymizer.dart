/// GPS-Anonymisierung für alle öffentlichen Standortanzeigen.
/// Rundet auf 2 Dezimalstellen ≈ 1,1 km Genauigkeit bei mittleren Breiten.
/// Ausnahmen (exakte Koordinaten zulässig):
///   - EmergencyAlert (SOS – Ersthelfer müssen die Person finden)
///   - EventItem (nutzerdefinierter Treffpunkt)
///   - FamilyCircle-Check-ins (direkte Terminabsprache unter Vertrauten)
class LocationAnonymizer {
  const LocationAnonymizer._();

  // 2 Dezimalstellen = ~1,1 km Auflösung.
  static const double _factor = 100.0;

  static double lat(double v) => (v * _factor).roundToDouble() / _factor;
  static double lng(double v) => (v * _factor).roundToDouble() / _factor;

  /// Anonymisiert ein Koordinatenpaar und gibt (lat, lng) zurück.
  static ({double lat, double lng}) fuzzy(double latitude, double longitude) =>
      (lat: lat(latitude), lng: lng(longitude));
}
