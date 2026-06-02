/// SKILL: mensaena-features
/// Spritpreise-Service — server-seitig vereinheitlicht via Edge-Function
/// 'fuel-prices' (siehe supabase/functions/fuel-prices/index.ts).
///
/// Quellen:
///   - AT: api.e-control.at (offizielle Behörden-API, kein Key)
///   - DE: creativecommons.tankerkoenig.de (Key liegt in private.push_config
///     unter 'tankerkoenig_api_key' — bis ein echter Key gesetzt wird,
///     liefert die Demo den gleichen Fake-Preis für alle Stationen
///     → Server gibt demo=true zurück, Client zeigt einen Hinweis).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class GasStation {
  const GasStation({
    required this.id,
    required this.brand,
    required this.name,
    required this.street,
    required this.place,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.isOpen,
    this.diesel,
    this.e5,
    this.e10,
  });
  final String id;
  final String brand;
  final String name;
  final String street;
  final String place;
  final double lat;
  final double lng;
  final double distanceKm;
  final bool isOpen;
  final double? diesel;
  final double? e5;
  final double? e10;
}

/// Antwort des Spritpreise-Services. [source] = 'e-control'|'tankerkoenig'|
/// 'none'. [demo] = true wenn der Server gerade den Tankerkönig-Demo-Key
/// nutzt (Preise sind dann nicht real und müssen gekennzeichnet werden).
class FuelPricesResult {
  const FuelPricesResult({
    required this.stations,
    required this.source,
    required this.demo,
  });
  final List<GasStation> stations;
  final String source;
  final bool demo;

  static const empty =
      FuelPricesResult(stations: [], source: 'none', demo: false);
}

class TankerkoenigService {
  TankerkoenigService._();

  /// Tankstellen rund um (lat,lng) im Radius (max 25 km). Land wird
  /// optional explizit übergeben ('AT'|'DE'|...); ansonsten leitet der
  /// Server es aus den Koordinaten ab.
  static Future<FuelPricesResult> nearby({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? country,
  }) async {
    try {
      final res = await sb.functions.invoke(
        'fuel-prices',
        body: {
          'lat': lat,
          'lng': lng,
          'rad_km': radiusKm,
          if (country != null) 'country': country,
        },
      );
      final data = res.data;
      if (data is! Map) return FuelPricesResult.empty;
      final stations = (data['stations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((s) => GasStation(
                id: (s['id'] as String?) ?? '',
                brand: (s['brand'] as String?) ?? '',
                name: (s['name'] as String?) ?? '',
                street: (s['street'] as String?) ?? '',
                place: (s['place'] as String?) ?? '',
                lat: (s['lat'] as num?)?.toDouble() ?? 0,
                lng: (s['lng'] as num?)?.toDouble() ?? 0,
                distanceKm: (s['distance_km'] as num?)?.toDouble() ?? 0,
                isOpen: s['is_open'] == true,
                diesel: (s['diesel'] as num?)?.toDouble(),
                e5: (s['e5'] as num?)?.toDouble(),
                e10: (s['e10'] as num?)?.toDouble(),
              ))
          .toList();
      return FuelPricesResult(
        stations: stations,
        source: (data['source'] as String?) ?? 'none',
        demo: data['demo'] == true,
      );
    } catch (e) {
      debugPrint('[FuelPrices] failed: $e');
      return FuelPricesResult.empty;
    }
  }
}
