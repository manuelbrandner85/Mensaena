/// SKILL: mensaena-features
/// Bundesagentur für Arbeit — Jobsuche-API. Kostenlos, kein Key.
/// Funktioniert OHNE GPS — Was+Wo Volltext-Suche, DE-weit.
///
/// Endpoint: https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v4/jobs
/// Doku: https://github.com/bundesAPI/jobsuche-api
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class JobAd {
  const JobAd({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.publicationDate,
    this.refNr,
    this.externalUrl,
  });
  final String id;
  final String title;
  final String company;
  final String location;
  final DateTime publicationDate;
  final String? refNr;
  final String? externalUrl;

  String get detailUrl => 'https://www.arbeitsagentur.de/jobsuche/jobdetail/${refNr ?? id}';
}

class BundesagenturJobsService {
  BundesagenturJobsService._();

  /// Suche nach Jobs. [was]=Beruf/Stichwort, [wo]=Ort oder PLZ (oder leer).
  /// [umkreis]=Radius in km um wo (default 25, max 200, 0=ohne).
  static Future<List<JobAd>> search({
    String? was,
    String? wo,
    int umkreis = 25,
    int page = 1,
    int size = 25,
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'size': '$size',
        if (was != null && was.trim().isNotEmpty) 'was': was.trim(),
        if (wo != null && wo.trim().isNotEmpty) 'wo': wo.trim(),
        if (wo != null && wo.trim().isNotEmpty) 'umkreis': '$umkreis',
      };
      final uri = Uri.https(
        'rest.arbeitsagentur.de',
        '/jobboerse/jobsuche-service/pc/v4/jobs',
        params,
      );
      final resp = await http.get(uri, headers: {
        // Pflicht-Header, sonst 403.
        'X-API-Key': 'jobboerse-jobsuche',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint(
            '[BA-Jobs] HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
        return const [];
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final ads = j['stellenangebote'] as List? ?? const [];
      return ads.whereType<Map<String, dynamic>>().map((a) {
        final arbeitsort =
            a['arbeitsort'] as Map<String, dynamic>? ?? const {};
        final ort = (arbeitsort['ort'] as String?) ?? '';
        final plz = (arbeitsort['plz'] as String?) ?? '';
        final region = (arbeitsort['region'] as String?) ?? '';
        final location = [
          if (plz.isNotEmpty) plz,
          if (ort.isNotEmpty) ort,
          if (region.isNotEmpty && region != ort) region,
        ].join(' ');
        final pubStr = a['aktuelleVeroeffentlichungsdatum'] as String? ??
            a['eintrittsdatum'] as String?;
        return JobAd(
          id: (a['hashId'] as String?) ?? (a['refnr'] as String?) ?? '',
          title: (a['titel'] as String?) ??
              (a['beruf'] as String?) ??
              'mensaena.jobUnknown',
          company: (a['arbeitgeber'] as String?) ?? '',
          location: location.trim(),
          publicationDate:
              DateTime.tryParse(pubStr ?? '')?.toUtc() ?? DateTime.now(),
          refNr: a['refnr'] as String?,
          externalUrl: a['externeUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[BA-Jobs] failed: $e');
      return const [];
    }
  }
}
