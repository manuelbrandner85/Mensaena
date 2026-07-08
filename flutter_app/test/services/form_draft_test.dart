import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/services/form_draft_service.dart';

void main() {
  group('FormDraft typed getters', () {
    const draft = FormDraft(data: {
      'title': 'Sofa',
      'price': '20',
      'negotiable': true,
      'radiusKm': 5,
      'lat': 48.2,
      'when': '2026-07-08T10:30:00.000',
      'wrongType': 42,
    });

    test('getString returns value only for String fields', () {
      expect(draft.getString('title'), 'Sofa');
      expect(draft.getString('wrongType'), isNull);
      expect(draft.getString('missing'), isNull);
    });

    test('getBool returns value only for bool fields', () {
      expect(draft.getBool('negotiable'), true);
      expect(draft.getBool('title'), isNull);
      expect(draft.getBool('missing'), isNull);
    });

    test('getDouble coerces num (int + double) and rejects strings', () {
      expect(draft.getDouble('radiusKm'), 5.0);
      expect(draft.getDouble('lat'), 48.2);
      expect(draft.getDouble('price'), isNull); // stored as String
      expect(draft.getDouble('missing'), isNull);
    });

    test('getDateTime parses ISO strings, null on bad/missing/non-string', () {
      expect(draft.getDateTime('when'),
          DateTime.parse('2026-07-08T10:30:00.000'));
      expect(draft.getDateTime('radiusKm'), isNull);
      expect(draft.getDateTime('missing'), isNull);
    });
  });
}
