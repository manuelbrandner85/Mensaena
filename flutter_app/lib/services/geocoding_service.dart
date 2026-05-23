import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// SKILL: mensaena-features
/// Nominatim Geocoding — kostenlos, kein API-Key. Pendant zu
/// `src/components/shared/AddressAutocomplete.tsx`.
/// Achtung: Nominatim verlangt User-Agent + max. 1 Request/Sekunde.
class GeocodingService {
  const GeocodingService._();

  static const _searchUrl = 'https://nominatim.openstreetmap.org/search';
  static const _ua = 'MensaenaApp/4.0 (https://www.mensaena.de)';

  /// Address-Search. Liefert max. [limit] Vorschlaege fuer [query].
  /// Beschraenkt auf DE/AT/CH per Default.
  static Future<List<AddressSuggestion>> search({
    required String query,
    int limit = 5,
    String countryCodes = 'de,at,ch',
  }) async {
    if (query.trim().length < 3) return const [];
    try {
      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limit',
        'countrycodes': countryCodes,
        'accept-language': 'de',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': _ua,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final list = jsonDecode(res.body) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.city,
    this.postcode,
    this.road,
  });

  final String displayName;
  final double lat;
  final double lng;
  final String? city;
  final String? postcode;
  final String? road;

  factory AddressSuggestion.fromJson(Map<String, dynamic> j) {
    final addr = j['address'] as Map<String, dynamic>?;
    return AddressSuggestion(
      displayName: j['display_name'] as String? ?? '',
      lat: double.tryParse(j['lat'] as String? ?? '') ?? 0,
      lng: double.tryParse(j['lon'] as String? ?? '') ?? 0,
      city: addr?['city'] as String? ??
          addr?['town'] as String? ??
          addr?['village'] as String?,
      postcode: addr?['postcode'] as String?,
      road: addr?['road'] as String?,
    );
  }

  String get shortLabel {
    final parts = <String>[];
    if (road != null) parts.add(road!);
    if (postcode != null) parts.add(postcode!);
    if (city != null) parts.add(city!);
    return parts.isEmpty ? displayName : parts.join(', ');
  }
}
