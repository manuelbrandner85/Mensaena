import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bundesländer-Codes 1:1 zur Web-`BundeslandCode`-Type.
enum BundeslandCode {
  bw('BW', 'Baden-Württemberg'),
  by('BY', 'Bayern'),
  be('BE', 'Berlin'),
  bb('BB', 'Brandenburg'),
  hb('HB', 'Bremen'),
  hh('HH', 'Hamburg'),
  he('HE', 'Hessen'),
  mv('MV', 'Mecklenburg-Vorpommern'),
  ni('NI', 'Niedersachsen'),
  nw('NW', 'Nordrhein-Westfalen'),
  rp('RP', 'Rheinland-Pfalz'),
  sl('SL', 'Saarland'),
  sn('SN', 'Sachsen'),
  st('ST', 'Sachsen-Anhalt'),
  sh('SH', 'Schleswig-Holstein'),
  th('TH', 'Thüringen'),
  national('NATIONAL', 'Deutschland (bundesweit)');

  const BundeslandCode(this.code, this.label);
  final String code;
  final String label;

  static BundeslandCode? fromCode(String? code) {
    if (code == null) return null;
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// Heuristische Zuordnung der ersten 1-2 PLZ-Ziffern zu Bundesländern,
/// 1:1 portiert aus `src/lib/geo/plz-mapping.ts`.
BundeslandCode? _plzPrefixToBundesland(String plz) {
  final trimmed = plz.replaceAll(RegExp(r'\s'), '');
  if (trimmed.length < 2) return null;
  final firstTwo = int.tryParse(trimmed.substring(0, 2));
  if (firstTwo == null) return null;

  if (firstTwo >= 1 && firstTwo <= 9) return BundeslandCode.sn;
  if (firstTwo == 10 || firstTwo == 12 || firstTwo == 13) {
    return BundeslandCode.be;
  }
  if (firstTwo == 14) return BundeslandCode.bb;
  if (firstTwo >= 15 && firstTwo <= 16) return BundeslandCode.bb;
  if (firstTwo >= 17 && firstTwo <= 19) return BundeslandCode.mv;
  if (firstTwo >= 20 && firstTwo <= 22) return BundeslandCode.hh;
  if (firstTwo >= 23 && firstTwo <= 25) return BundeslandCode.sh;
  if (firstTwo == 26 || firstTwo == 27) return BundeslandCode.ni;
  if (firstTwo == 28) return BundeslandCode.hb;
  if (firstTwo >= 29 && firstTwo <= 31) return BundeslandCode.ni;
  if (firstTwo >= 32 && firstTwo <= 33) return BundeslandCode.nw;
  if (firstTwo >= 34 && firstTwo <= 36) return BundeslandCode.he;
  if (firstTwo >= 37 && firstTwo <= 38) return BundeslandCode.ni;
  if (firstTwo == 39) return BundeslandCode.st;
  if (firstTwo >= 40 && firstTwo <= 48) return BundeslandCode.nw;
  if (firstTwo == 49) return BundeslandCode.ni;
  if (firstTwo >= 50 && firstTwo <= 53) return BundeslandCode.nw;
  if (firstTwo >= 54 && firstTwo <= 56) return BundeslandCode.rp;
  if (firstTwo == 57) return BundeslandCode.nw;
  if (firstTwo >= 58 && firstTwo <= 59) return BundeslandCode.nw;
  if (firstTwo >= 60 && firstTwo <= 65) return BundeslandCode.he;
  if (firstTwo == 66) return BundeslandCode.sl;
  if (firstTwo == 67) return BundeslandCode.rp;
  if (firstTwo == 68) return BundeslandCode.bw;
  if (firstTwo >= 69 && firstTwo <= 79) return BundeslandCode.bw;
  if (firstTwo >= 80 && firstTwo <= 87) return BundeslandCode.by;
  if (firstTwo == 88) return BundeslandCode.bw;
  if (firstTwo >= 89 && firstTwo <= 97) return BundeslandCode.by;
  if (firstTwo >= 98 && firstTwo <= 99) return BundeslandCode.th;
  return null;
}

BundeslandCode plzToBundesland(String? plz) {
  if (plz == null) return BundeslandCode.national;
  return _plzPrefixToBundesland(plz) ?? BundeslandCode.national;
}

/// Grobe Bounding-Box-Heuristik. Wird benutzt, wenn PLZ nicht verfügbar ist.
BundeslandCode coordsToBundesland(double lat, double lon) {
  // Stadtstaaten zuerst.
  if (lat >= 53.39 && lat <= 53.74 && lon >= 8.10 && lon <= 9.30) {
    return BundeslandCode.hb;
  }
  if (lat >= 53.39 && lat <= 53.74 && lon >= 9.71 && lon <= 10.33) {
    return BundeslandCode.hh;
  }
  if (lat >= 52.34 && lat <= 52.68 && lon >= 13.08 && lon <= 13.77) {
    return BundeslandCode.be;
  }
  if (lat >= 47.27 && lat <= 50.56 && lon >= 9.00 && lon <= 13.84) {
    return BundeslandCode.by;
  }
  if (lat >= 47.53 && lat <= 49.79 && lon >= 7.51 && lon <= 10.50) {
    return BundeslandCode.bw;
  }
  if (lat >= 49.11 && lat <= 50.94 && lon >= 8.00 && lon <= 10.24) {
    return BundeslandCode.he;
  }
  if (lat >= 50.32 && lat <= 51.65 && lon >= 5.86 && lon <= 9.46) {
    return BundeslandCode.nw;
  }
  if (lat >= 49.11 && lat <= 50.94 && lon >= 6.11 && lon <= 8.51) {
    return BundeslandCode.rp;
  }
  if (lat >= 49.11 && lat <= 49.64 && lon >= 6.36 && lon <= 7.40) {
    return BundeslandCode.sl;
  }
  if (lat >= 51.32 && lat <= 53.89 && lon >= 6.65 && lon <= 11.59) {
    return BundeslandCode.ni;
  }
  if (lat >= 53.36 && lat <= 55.07 && lon >= 7.86 && lon <= 11.32) {
    return BundeslandCode.sh;
  }
  if (lat >= 53.10 && lat <= 54.71 && lon >= 10.59 && lon <= 14.41) {
    return BundeslandCode.mv;
  }
  if (lat >= 51.36 && lat <= 53.56 && lon >= 11.27 && lon <= 14.77) {
    return BundeslandCode.bb;
  }
  if (lat >= 50.17 && lat <= 51.69 && lon >= 11.87 && lon <= 15.04) {
    return BundeslandCode.sn;
  }
  if (lat >= 50.17 && lat <= 53.04 && lon >= 10.55 && lon <= 13.18) {
    return BundeslandCode.st;
  }
  return BundeslandCode.national;
}

/// Ein gesetzlicher Feiertag.
class Holiday {
  const Holiday({
    required this.name,
    required this.date,
    required this.state,
    required this.isRegional,
    this.note,
  });

  final String name;
  final DateTime date;
  final BundeslandCode state;
  final bool isRegional;
  final String? note;
}

const _nationalHolidays = {
  'Neujahrstag',
  'Karfreitag',
  'Ostermontag',
  'Tag der Arbeit',
  'Christi Himmelfahrt',
  'Pfingstmontag',
  'Tag der Deutschen Einheit',
  '1. Weihnachtstag',
  '2. Weihnachtstag',
};

/// Lädt deutsche Feiertage von feiertage-api.de (kostenlos, kein API-Key).
/// Cacht 24h in SharedPreferences.
class HolidayService {
  HolidayService._();

  static const _ttl = Duration(hours: 24);

  static String _cacheKey(int year, BundeslandCode state) =>
      'holidays.$year.${state.code}';

  static Future<List<Holiday>> fetch({
    required int year,
    required BundeslandCode state,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cacheKey(year, state);
      final tsKey = '$cacheKey.ts';
      final cached = prefs.getString(cacheKey);
      final ts = prefs.getInt(tsKey);
      if (cached != null && ts != null) {
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age < _ttl.inMilliseconds) {
          return _decode(cached, state);
        }
      }

      final stateParam =
          state == BundeslandCode.national ? 'NATIONAL' : state.code;
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
      ),);
      final res = await dio.get<dynamic>(
        'https://feiertage-api.de/api/',
        queryParameters: {'jahr': year, 'nur_land': stateParam},
      );
      if (res.statusCode != 200) {
        return cached != null ? _decode(cached, state) : const [];
      }
      final body =
          res.data is String ? res.data as String : jsonEncode(res.data);
      await prefs.setString(cacheKey, body);
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      return _decode(body, state);
    } catch (e, st) {
      debugPrint('HolidayService.fetch failed: $e\n$st');
      return const [];
    }
  }

  static List<Holiday> _decode(String body, BundeslandCode state) {
    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) return const [];
      final out = <Holiday>[];
      raw.forEach((name, data) {
        if (data is! Map<String, dynamic>) return;
        final dateStr = data['datum'] as String?;
        if (dateStr == null) return;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return;
        final isNational = _nationalHolidays.contains(name);
        out.add(Holiday(
          name: name,
          date: date,
          state: isNational ? BundeslandCode.national : state,
          isRegional: !isNational,
          note: data['hinweis'] as String?,
        ),);
      });
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    } catch (_) {
      return const [];
    }
  }
}
