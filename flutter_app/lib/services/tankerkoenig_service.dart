/// SKILL: mensaena-features
/// Tankerkönig API — DE-Spritpreise von Aral, Shell, ESSO, Total etc.
/// Kostenlos via https://creativecommons.tankerkoenig.de/ (CC-BY).
/// Benötigt einen API-Key; Demo-Key ist im freien Tier (1000/h shared).
///
/// Endpoint: https://creativecommons.tankerkoenig.de/json/list.php
///   ?lat={lat}&lng={lng}&rad={radiusKm}&type=all&apikey={key}
///
/// Doku: https://creativecommons.tankerkoenig.de/
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

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

class TankerkoenigService {
  TankerkoenigService._();

  // Demo-Key (öffentlich). Eigenen Key kostenlos via Form anfragen wenn
  // 1000 req/h shared limit reached:
  // https://creativecommons.tankerkoenig.de/#register
  static const _apiKey = '00000000-0000-0000-0000-000000000002';

  /// Tankstellen rund um (lat,lng) im Radius (max 25 km).
  static Future<List<GasStation>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    try {
      final uri = Uri.parse(
        'https://creativecommons.tankerkoenig.de/json/list.php'
        '?lat=$lat&lng=$lng&rad=${radiusKm.clamp(1, 25)}&type=all&sort=dist&apikey=$_apiKey',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        debugPrint('[Tankerkoenig] HTTP ${resp.statusCode}');
        return const [];
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (j['ok'] != true) return const [];
      final stations = j['stations'] as List? ?? const [];
      return stations
          .whereType<Map<String, dynamic>>()
          .map((s) => GasStation(
                id: s['id'] as String,
                brand: (s['brand'] as String?) ?? '',
                name: (s['name'] as String?) ?? '',
                street: '${s['street'] ?? ''} ${s['houseNumber'] ?? ''}'.trim(),
                place: (s['place'] as String?) ?? '',
                lat: (s['lat'] as num).toDouble(),
                lng: (s['lng'] as num).toDouble(),
                distanceKm: (s['dist'] as num?)?.toDouble() ?? 0,
                isOpen: s['isOpen'] == true,
                diesel: (s['diesel'] as num?)?.toDouble(),
                e5: (s['e5'] as num?)?.toDouble(),
                e10: (s['e10'] as num?)?.toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('[Tankerkoenig] failed: $e');
      return const [];
    }
  }
}
