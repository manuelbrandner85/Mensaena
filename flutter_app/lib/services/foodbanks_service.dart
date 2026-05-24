import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// SKILL: mensaena-features
/// Statisches Foodbank-Verzeichnis für die wichtigsten Dachverbände in
/// DE/AT/CH/IT/ES/FR/TR/RU/GB/US/IE. Quelle: `assets/data/foodbanks.json`.
///
/// Daten sind absichtlich kuratiert (HQ + Dachverband-Suchlink) und
/// werden im Repo gepflegt — keine API-Calls, kein Netzwerk, kein RLS.
class Foodbank {
  const Foodbank({
    required this.country,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.website,
    required this.lat,
    required this.lng,
    required this.findLocalUrl,
    required this.descriptionDe,
    required this.descriptionEn,
  });

  final String country;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String website;
  final double lat;
  final double lng;
  final String findLocalUrl;
  final String descriptionDe;
  final String descriptionEn;

  factory Foodbank.fromJson(Map<String, dynamic> json) => Foodbank(
        country: json['country'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        findLocalUrl: json['find_local_url'] as String,
        descriptionDe: json['description_de'] as String? ?? '',
        descriptionEn: json['description_en'] as String? ?? '',
      );
}

class FoodbanksService {
  FoodbanksService._();

  static List<Foodbank>? _cache;

  static Future<List<Foodbank>> all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/foodbanks.json');
    final list = json.decode(raw) as List<dynamic>;
    _cache = list
        .map((e) => Foodbank.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
  }

  static Future<List<Foodbank>> forCountry(String code) async {
    final upper = code.toUpperCase();
    final list = await all();
    return list.where((f) => f.country == upper).toList(growable: false);
  }

  static Future<Foodbank?> nearest(double lat, double lng) async {
    final list = await all();
    if (list.isEmpty) return null;
    Foodbank? best;
    double bestDist = double.infinity;
    for (final f in list) {
      final d = _haversineKm(lat, lng, f.lat, f.lng);
      if (d < bestDist) {
        bestDist = d;
        best = f;
      }
    }
    return best;
  }

  /// Haversine in km. Earth radius 6371 km.
  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
