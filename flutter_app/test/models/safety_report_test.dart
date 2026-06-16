import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/models/safety_report.dart';

/// Reine Dart-Logik-Tests für SafetyReport — kein Netzwerk, kein Supabase.
void main() {
  group('SafetyReport.fromJson', () {
    test('mappt alle Felder inkl. distance_km aus der RPC', () {
      final r = SafetyReport.fromJson({
        'id': 'r1',
        'reporter_id': 'u1',
        'title': 'Aufgebrochenes Auto',
        'description': 'Seitenscheibe eingeschlagen',
        'incident_type': 'einbruch',
        'anonymous': false,
        'location_address': 'Hauptstr. 1',
        'location_lat': 48.137154,
        'location_lng': 11.576124,
        'happened_at': '2026-06-15T08:00:00Z',
        'image_urls': ['https://x/1.jpg', 'https://x/2.jpg'],
        'status': 'active',
        'upvote_count': 4,
        'created_at': '2026-06-15T09:00:00Z',
        'distance_km': 1.2,
      });

      expect(r.id, 'r1');
      expect(r.reporterId, 'u1');
      expect(r.incidentType, 'einbruch');
      expect(r.anonymous, false);
      expect(r.imageUrls.length, 2);
      expect(r.upvoteCount, 4);
      expect(r.distanceKm, 1.2);
      expect(r.happenedAt!.isUtc, true);
    });

    test('greift auf Defaults zurück bei fehlenden/leeren Feldern', () {
      final r = SafetyReport.fromJson(<String, dynamic>{});
      expect(r.id, '');
      expect(r.incidentType, SafetyIncidentType.other);
      expect(r.anonymous, false);
      expect(r.status, 'active');
      expect(r.upvoteCount, 0);
      expect(r.imageUrls, isEmpty);
      expect(r.reporterId, isNull);
      expect(r.distanceKm, isNull);
    });
  });

  group('Anonymität', () {
    test('isAnonymous = true wenn anonymous-Flag gesetzt', () {
      final r = SafetyReport.fromJson({
        'id': 'a',
        'reporter_id': 'u1',
        'title': 't',
        'anonymous': true,
      });
      expect(r.isAnonymous, true);
    });

    test('isAnonymous = true wenn reporter_id von RPC genullt wurde', () {
      final r = SafetyReport.fromJson({
        'id': 'a',
        'reporter_id': null,
        'title': 't',
        'anonymous': false,
      });
      // RPC hat reporter_id entfernt → nicht auflösbar → anonym anzeigen.
      expect(r.isAnonymous, true);
    });

    test('isAnonymous = false bei echtem Melder', () {
      final r = SafetyReport.fromJson({
        'id': 'a',
        'reporter_id': 'u1',
        'title': 't',
        'anonymous': false,
      });
      expect(r.isAnonymous, false);
    });
  });

  group('Standort-Anonymisierung (≈1 km)', () {
    test('displayLat/displayLng runden auf 2 Dezimalstellen', () {
      final r = SafetyReport.fromJson({
        'id': 'a',
        'reporter_id': 'u1',
        'title': 't',
        'location_lat': 48.137154,
        'location_lng': 11.576124,
      });
      expect(r.displayLat, 48.14);
      expect(r.displayLng, 11.58);
    });

    test('null bleibt null', () {
      final r = SafetyReport.fromJson({'id': 'a', 'title': 't'});
      expect(r.displayLat, isNull);
      expect(r.displayLng, isNull);
    });
  });

  group('toInsert', () {
    test('enthält nur gesetzte Felder, keine reporter_id/id/counts', () {
      final r = SafetyReport(
        id: '',
        reporterId: null,
        title: 'Verdächtige Person',
        description: 'Klingelt an mehreren Türen',
        incidentType: SafetyIncidentType.verdaechtig,
        anonymous: true,
        status: 'active',
        locationAddress: 'Lindenweg 3',
        locationLat: 50.1,
        locationLng: 8.6,
        happenedAt: DateTime.utc(2026, 6, 15, 7),
      );
      final m = r.toInsert();

      expect(m['title'], 'Verdächtige Person');
      expect(m['incident_type'], 'verdaechtig');
      expect(m['anonymous'], true);
      expect(m['location_address'], 'Lindenweg 3');
      expect(m['location_lat'], 50.1);
      expect(m['happened_at'], '2026-06-15T07:00:00.000Z');
      expect(m.containsKey('reporter_id'), false);
      expect(m.containsKey('id'), false);
      expect(m.containsKey('upvote_count'), false);
    });

    test('lässt leere optionale Felder weg', () {
      const r = SafetyReport(
        id: '',
        reporterId: null,
        title: 'Nur Titel',
        incidentType: SafetyIncidentType.other,
        anonymous: false,
        status: 'active',
      );
      final m = r.toInsert();
      expect(m.containsKey('description'), false);
      expect(m.containsKey('location_address'), false);
      expect(m.containsKey('location_lat'), false);
      expect(m.containsKey('image_urls'), false);
    });
  });

  test('SafetyIncidentType.all enthält alle 7 Typen', () {
    expect(SafetyIncidentType.all, hasLength(7));
    expect(SafetyIncidentType.all, contains('einbruch'));
    expect(SafetyIncidentType.all, contains('fundgegenstand'));
    expect(SafetyIncidentType.all.last, 'other');
  });
}
