/// SKILL: mensaena-features
/// Bundesagentur für Arbeit — Jobsuche-API.
/// https://jobsuche.api.bund.dev/ (öffentlich, kein API-Key)
/// Endpoint: https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v4/jobs
library;

import 'dart:convert';
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
