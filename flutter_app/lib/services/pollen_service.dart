/// SKILL: mensaena-features
/// Pollenflug via Open-Meteo Air-Quality API — gratis, KEIN API-Key, Europa.
///
/// Gleicher Endpoint wie die Luftqualität (air-quality-api.open-meteo.com),
/// nur andere `current`-Felder. Liefert die aktuelle Pollenbelastung für die
/// häufigsten allergenen Pflanzen in grains/m³ plus einen 0–4-Belastungslevel.
///
/// API: https://open-meteo.com/en/docs/air-quality-api  (pollen, nur Europa)
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PollenSample {
  const PollenSample({
    required this.type,
    required this.value,
    required this.unit,
    required this.measuredAt,
  });

  /// 'grass','birch','alder','mugwort','olive','ragweed'
  final String type;
  final double value; // grains/m³
  final String unit;
  final DateTime measuredAt;

  /// 0=keine, 1=niedrig, 2=mäßig, 3=hoch, 4=sehr hoch.
  /// Grobe, typ-unabhängige Schwellen (grains/m³) — für eine Ampel ausreichend.
  int get level {
    if (value <= 0) return 0;
    if (value < 10) return 1;
    if (value < 30) return 2;
    if (value < 70) return 3;
    return 4;
  }
}

class PollenService {
  const PollenService._();

  static const Map<String, String> _apiToType = {
    'grass_pollen': 'grass',
    'birch_pollen': 'birch',
    'alder_pollen': 'alder',
    'mugwort_pollen': 'mugwort',
    'olive_pollen': 'olive',
    'ragweed_pollen': 'ragweed',
  };

  /// Aktuelle Pollenbelastung am GPS-Punkt. Gibt je ein Sample pro Pollentyp
  /// zurück (nur Typen, für die die API einen Wert liefert). Leere Liste bei
  /// Fehler oder außerhalb Europas (API liefert dort keine Pollen).
  static Future<List<PollenSample>> current({
    required double lat,
    required double lng,
  }) async {
    final fields = _apiToType.keys.join(',');
    final uri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lng'
      '&current=$fields',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final current = j['current'] as Map<String, dynamic>? ?? const {};
      final units = j['current_units'] as Map<String, dynamic>? ?? const {};
      final timeIso = current['time'] as String?;
      final measuredAt =
          DateTime.tryParse(timeIso ?? '')?.toUtc() ?? DateTime.now();

      final out = <PollenSample>[];
      for (final entry in _apiToType.entries) {
        final raw = current[entry.key];
        if (raw == null) continue;
        out.add(PollenSample(
          type: entry.value,
          value: (raw as num).toDouble(),
          unit: (units[entry.key] as String?) ?? 'grains/m³',
          measuredAt: measuredAt,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
