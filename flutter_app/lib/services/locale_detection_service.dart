/// SKILL: mensaena-features
/// LocaleDetectionService — GPS-Standort → ISO-Country-Code → App-Sprache.
///
/// Verwendet `geolocator` für die aktuelle Position und `geocoding` (Android
/// nutzt intern OS-Geocoder, keine externe API nötig — kein API-Key) für die
/// reverse-geocoded Ländercode-Ermittlung. Wenn `geocoding` versagt (z. B.
/// im Emulator), fällt der Service auf einen statischen Bounding-Box-Lookup
/// für DACH/IT/FR/ES/TR/RU zurück.
///
/// Mapping ISO-3166-1-alpha-2 → unsere 7 unterstützten Locales:
///   DE/AT/CH/LI/LU → de
///   IT/SM/VA       → it
///   ES/AD          → es
///   FR/BE/MC       → fr
///   TR/CY          → tr
///   RU/BY/KZ       → ru
///   sonst          → en
library;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocaleDetectionService {
  const LocaleDetectionService._();

  static const Map<String, String> _countryToLang = {
    // Deutsch
    'DE': 'de', 'AT': 'de', 'CH': 'de', 'LI': 'de', 'LU': 'de',
    // Italienisch
    'IT': 'it', 'SM': 'it', 'VA': 'it',
    // Spanisch
    'ES': 'es', 'AD': 'es', 'MX': 'es', 'AR': 'es', 'CL': 'es',
    'CO': 'es', 'PE': 'es', 'VE': 'es', 'UY': 'es', 'PY': 'es',
    'BO': 'es', 'EC': 'es', 'CR': 'es', 'CU': 'es', 'DO': 'es',
    'GT': 'es', 'HN': 'es', 'NI': 'es', 'PA': 'es', 'SV': 'es',
    // Französisch
    'FR': 'fr', 'BE': 'fr', 'MC': 'fr', 'SN': 'fr', 'CI': 'fr',
    // Türkisch
    'TR': 'tr', 'CY': 'tr',
    // Russisch
    'RU': 'ru', 'BY': 'ru', 'KZ': 'ru', 'KG': 'ru', 'TJ': 'ru',
  };

  /// Liefert das passende Locale für den aktuellen Standort oder null,
  /// wenn keine Position ermittelbar oder Berechtigung verweigert.
  static Future<Locale?> detect() async {
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission p = perm;
      if (perm == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );
      final iso = await _reverseGeocode(pos.latitude, pos.longitude);
      if (iso == null) return null;
      final lang = _countryToLang[iso.toUpperCase()] ?? 'en';
      return Locale(lang);
    } catch (_) {
      return null;
    }
  }

  /// Versucht zuerst Plattform-Geocoder, fällt dann auf Bounding-Boxes
  /// zurück, falls Geocoding versagt (oft im Android-Emulator).
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final iso = placemarks.first.isoCountryCode?.trim();
        if (iso != null && iso.isNotEmpty) return iso;
      }
    } catch (_) {/* fallback */}
    return _bboxFallback(lat, lng);
  }

  /// Sehr grobe Bounding-Boxes — letzte Rettung wenn Geocoder offline.
  static String? _bboxFallback(double lat, double lng) {
    if (lat >= 47 && lat <= 55 && lng >= 5.5 && lng <= 15.2) return 'DE';
    if (lat >= 46 && lat <= 49 && lng >= 9.5 && lng <= 17.2) return 'AT';
    if (lat >= 45.5 && lat <= 47.9 && lng >= 5.9 && lng <= 10.5) return 'CH';
    if (lat >= 35.5 && lat <= 47.1 && lng >= 6.6 && lng <= 18.5) return 'IT';
    if (lat >= 35.9 && lat <= 43.9 && lng >= -9.5 && lng <= 4.3) return 'ES';
    if (lat >= 42.3 && lat <= 51.1 && lng >= -5.2 && lng <= 8.3) return 'FR';
    if (lat >= 35.8 && lat <= 42.1 && lng >= 25.7 && lng <= 44.8) return 'TR';
    if (lat >= 41.2 && lat <= 81.9 && lng >= 19.6 && lng <= 180.0) return 'RU';
    return null;
  }
}
