/// SKILL: mensaena-features
/// Bundesagentur für Arbeit — Jobsuche-API.
/// https://jobsuche.api.bund.dev/ (öffentlich, kein API-Key)
/// Endpoint: https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v4/jobs
///
/// Zusätzlich: `JobPortal` + `JobPortalsService` für die kuratierte
/// Liste offizieller + privater Jobportale pro Land (assets/data/job_portals.json).
/// EURES-Direkt-API ist instabil; deshalb pragmatischer Fallback auf statische
/// Direkt-Such-Links pro Land — der Klick öffnet das Portal im Browser.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class JobOffer {
  const JobOffer({
    required this.refnr,
    required this.title,
    this.employer,
    this.location,
    this.publishedAt,
    this.modifiedAt,
    this.profession,
  });

  final String refnr;
  final String title;
  final String? employer;
  final String? location;
  final DateTime? publishedAt;
  final DateTime? modifiedAt;
  final String? profession;

  /// Direktlink zum Jobbörse-Eintrag.
  String get externalUrl =>
      'https://www.arbeitsagentur.de/jobsuche/jobdetail/$refnr';
}

class JobsService {
  const JobsService._();

  /// Sucht Jobs in einem Postleitzahl-Umkreis.
  /// [plz]    — z. B. '10115' (Berlin Mitte)
  /// [umkreis] — Radius in km (5, 10, 25, 50, 100, 200)
  /// [was]    — Suchbegriff (optional)
  static Future<List<JobOffer>> search({
    required String plz,
    int umkreis = 25,
    String? was,
    int size = 30,
  }) async {
    try {
      final params = <String, String>{
        'wo': plz,
        'umkreis': umkreis.toString(),
        'size': size.toString(),
        'page': '1',
      };
      if (was != null && was.isNotEmpty) params['was'] = was;
      final uri = Uri.https(
        'rest.arbeitsagentur.de',
        '/jobboerse/jobsuche-service/pc/v4/jobs',
        params,
      );
      final r = await http.get(uri, headers: {
        // Bundesagentur erfordert diesen Demo-Header.
        'X-API-Key': 'jobboerse-jobsuche',
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final stellen = j['stellenangebote'] as List? ?? const [];
      return stellen
          .whereType<Map<String, dynamic>>()
          .map((m) {
            final ort = m['arbeitsort'] as Map<String, dynamic>?;
            return JobOffer(
              refnr: m['refnr'] as String? ?? '',
              title: (m['titel'] as String?) ??
                  (m['beruf'] as String?) ??
                  'Stellenangebot',
              employer: m['arbeitgeber'] as String?,
              location: ort != null
                  ? '${ort['plz'] ?? ''} ${ort['ort'] ?? ''}'.trim()
                  : null,
              profession: m['beruf'] as String?,
              publishedAt: m['aktuelleVeroeffentlichungsdatum'] != null
                  ? DateTime.tryParse(
                      m['aktuelleVeroeffentlichungsdatum'] as String)
                  : null,
              modifiedAt: m['modifikationsTimestamp'] != null
                  ? DateTime.tryParse(m['modifikationsTimestamp'] as String)
                  : null,
            );
          })
          .where((o) => o.refnr.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Kuratiertes Job-Portal pro Land. Quelle: `assets/data/job_portals.json`.
class JobPortal {
  const JobPortal({
    required this.country,
    required this.name,
    required this.operator,
    required this.website,
    required this.searchUrl,
    required this.descriptionDe,
    required this.descriptionEn,
    required this.official,
  });

  final String country;
  final String name;
  final String operator;
  final String website;
  final String searchUrl;
  final String descriptionDe;
  final String descriptionEn;
  final bool official;

  factory JobPortal.fromJson(Map<String, dynamic> j) => JobPortal(
        country: (j['country'] as String? ?? '').toUpperCase(),
        name: j['name'] as String? ?? '',
        operator: j['operator'] as String? ?? '',
        website: j['website'] as String? ?? '',
        searchUrl: j['search_url'] as String? ?? j['website'] as String? ?? '',
        descriptionDe: j['description_de'] as String? ?? '',
        descriptionEn: j['description_en'] as String? ?? '',
        official: j['official'] as bool? ?? false,
      );
}

class JobPortalsService {
  const JobPortalsService._();

  static List<JobPortal>? _cache;

  static Future<List<JobPortal>> all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/job_portals.json');
    final list = json.decode(raw) as List<dynamic>;
    _cache = list
        .map((e) => JobPortal.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
  }

  /// Portale fuer ein Land + den EU-weiten EURES-Eintrag.
  static Future<List<JobPortal>> forCountry(String code) async {
    final upper = code.toUpperCase();
    final list = await all();
    final country = list.where((p) => p.country == upper).toList();
    final eu = list.where((p) => p.country == 'EU').toList();
    return [...country, ...eu];
  }
}

