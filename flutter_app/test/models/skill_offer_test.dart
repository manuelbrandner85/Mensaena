import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/models/skill_offer.dart';

void main() {
  group('SkillOffer.fromJson', () {
    test('mappt alle Pflichtfelder korrekt', () {
      final s = SkillOffer.fromJson({
        'id': 'so-1',
        'user_id': 'u-1',
        'title': 'Python-Kurs',
        'description': 'Grundlagen für Einsteiger',
        'created_at': '2026-06-15T10:00:00Z',
        'updated_at': '2026-06-15T10:00:00Z',
        'skill_category': 'it',
        'level': 'anfaenger',
        'is_free': false,
        'hourly_rate': 20.0,
        'is_online': true,
        'is_active': true,
        'location_address': 'Berlin Mitte',
      });

      expect(s.id, 'so-1');
      expect(s.userId, 'u-1');
      expect(s.title, 'Python-Kurs');
      expect(s.skillCategory, 'it');
      expect(s.level, 'anfaenger');
      expect(s.isFree, false);
      expect(s.hourlyRate, 20.0);
      expect(s.isOnline, true);
      expect(s.isActive, true);
      expect(s.locationAddress, 'Berlin Mitte');
      expect(s.createdAt.isUtc, true);
    });

    test('verwendet Defaults bei fehlenden optionalen Feldern', () {
      final s = SkillOffer.fromJson({
        'id': 'so-2',
        'user_id': 'u-2',
        'title': 'Gitarre',
        'description': 'Für Anfänger',
        'created_at': '2026-06-15T10:00:00Z',
        'updated_at': '2026-06-15T10:00:00Z',
      });

      expect(s.skillCategory, isNull);
      expect(s.level, isNull);
      expect(s.isFree, true);
      expect(s.hourlyRate, isNull);
      expect(s.isOnline, false);
      expect(s.isActive, true);
      expect(s.locationAddress, isNull);
    });

    test('toJson enthält alle gesetzten Felder', () {
      final s = SkillOffer.fromJson({
        'id': 'so-3',
        'user_id': 'u-3',
        'title': 'Yoga',
        'description': 'Hatha Yoga für alle Level',
        'created_at': '2026-06-16T08:00:00Z',
        'updated_at': '2026-06-16T08:00:00Z',
        'skill_category': 'sport',
        'is_free': true,
        'is_online': false,
        'is_active': true,
      });

      final j = s.toJson();
      expect(j['id'], 'so-3');
      expect(j['user_id'], 'u-3');
      expect(j['skill_category'], 'sport');
      expect(j['is_free'], true);
      expect(j['is_online'], false);
    });
  });
}
