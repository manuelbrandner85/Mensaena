import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/providers/public_holidays_provider.dart';
import 'package:mensaena/services/holidays_service.dart';

void main() {
  group('countryCodeFromLocale', () {
    test('de maps to DE', () {
      expect(countryCodeFromLocale('de'), 'DE');
    });

    test('en maps to GB', () {
      expect(countryCodeFromLocale('en'), 'GB');
    });

    test('it maps to IT', () {
      expect(countryCodeFromLocale('it'), 'IT');
    });

    test('es maps to ES', () {
      expect(countryCodeFromLocale('es'), 'ES');
    });

    test('fr maps to FR', () {
      expect(countryCodeFromLocale('fr'), 'FR');
    });

    test('tr maps to TR', () {
      expect(countryCodeFromLocale('tr'), 'TR');
    });

    test('ru maps to RU', () {
      expect(countryCodeFromLocale('ru'), 'RU');
    });

    test('unknown language falls back to DE', () {
      expect(countryCodeFromLocale('zh'), 'DE');
    });
  });

  group('HolidaysService.parseFloatingDate', () {
    test('parses API date as local calendar date (not UTC-shifted)', () {
      final d = HolidaysService.parseFloatingDate('2026-07-06');
      expect(d.year, 2026);
      expect(d.month, 7);
      expect(d.day, 6);
      expect(d.isUtc, isFalse);
      // Mitternacht lokal — keine Zeitzonen-Verschiebung auf den Vor-/Folgetag.
      expect(d.hour, 0);
      expect(d.minute, 0);
    });

    test('ignores a trailing time component', () {
      final d = HolidaysService.parseFloatingDate('2026-12-25T00:00:00');
      expect(d.year, 2026);
      expect(d.month, 12);
      expect(d.day, 25);
      expect(d.isUtc, isFalse);
    });

    test('parsed date is today when it matches DateTime.now()', () {
      final now = DateTime.now();
      final iso =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final h = Holiday(
        date: HolidaysService.parseFloatingDate(iso),
        localName: 'Heute',
        name: 'Today',
      );
      expect(h.isToday, isTrue);
      expect(h.daysFromNow, 0);
    });
  });

  group('Holiday', () {
    test('isToday returns true for today', () {
      final now = DateTime.now();
      final h = Holiday(
        date: DateTime.utc(now.year, now.month, now.day),
        localName: 'Test',
        name: 'Test Holiday',
      );
      expect(h.isToday, isTrue);
    });

    test('daysFromNow returns 0 for today', () {
      final now = DateTime.now();
      final h = Holiday(
        date: DateTime.utc(now.year, now.month, now.day),
        localName: 'Test',
        name: 'Test Holiday',
      );
      expect(h.daysFromNow, 0);
    });

    test('daysFromNow returns positive for future date', () {
      final now = DateTime.now();
      final future = now.add(const Duration(days: 5));
      final h = Holiday(
        date: DateTime.utc(future.year, future.month, future.day),
        localName: 'Future',
        name: 'Future Holiday',
      );
      expect(h.daysFromNow, greaterThan(0));
    });

    test('daysFromNow returns negative for past date', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 3));
      final h = Holiday(
        date: DateTime.utc(past.year, past.month, past.day),
        localName: 'Past',
        name: 'Past Holiday',
      );
      expect(h.daysFromNow, lessThan(0));
    });
  });
}
