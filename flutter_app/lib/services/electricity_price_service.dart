/// SKILL: mensaena-features
/// Börsen-Strompreise (Day-Ahead, DE-LU) via Energy-Charts API (Fraunhofer ISE)
/// — gratis, KEIN API-Key. Liefert stündliche Großhandelspreise; wir rechnen
/// EUR/MWh in ct/kWh um, damit der Wert für Haushalte greifbar ist.
///
/// API: https://api.energy-charts.info/price?bzn=DE-LU
///   { "unix_seconds": [...], "price": [...], "unit": "EUR/MWh" }
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PricePoint {
  const PricePoint({required this.time, required this.ctPerKwh});
  final DateTime time; // lokale Zeit
  final double ctPerKwh; // Cent pro kWh (Börsenpreis, ohne Steuern/Netz)
}

class ElectricityPriceService {
  const ElectricityPriceService._();

  /// Tages-Day-Ahead-Preise (heute + ggf. morgen, sobald veröffentlicht).
  /// Leere Liste bei Fehler.
  static Future<List<PricePoint>> dayAhead({String bzn = 'DE-LU'}) async {
    final uri = Uri.parse('https://api.energy-charts.info/price?bzn=$bzn');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final secs = (j['unix_seconds'] as List?) ?? const [];
      final prices = (j['price'] as List?) ?? const [];
      final unit = (j['unit'] as String?) ?? 'EUR/MWh';
      // EUR/MWh -> ct/kWh : 1 EUR/MWh = 0.1 ct/kWh
      final factor = unit.toUpperCase().contains('MWH') ? 0.1 : 1.0;
      final n = secs.length < prices.length ? secs.length : prices.length;
      final out = <PricePoint>[];
      for (var i = 0; i < n; i++) {
        final s = (secs[i] as num?)?.toInt();
        final p = (prices[i] as num?)?.toDouble();
        if (s == null || p == null) continue;
        out.add(PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch(s * 1000).toLocal(),
          ctPerKwh: p * factor,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
