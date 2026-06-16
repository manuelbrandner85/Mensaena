import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/services/avatar_generator_service.dart';

void main() {
  group('AvatarGenerator', () {
    test('diceBear returns a valid DiceBear v9 PNG URL', () {
      final url = AvatarGenerator.diceBear(seed: 'test-user');
      expect(url, contains('api.dicebear.com/9.x/'));
      expect(url, contains('/png?'));
      expect(url, contains('seed=test-user'));
    });

    test('diceBear accepts custom style and size', () {
      final url = AvatarGenerator.diceBear(
          seed: 'abc', style: 'avataaars', size: 128);
      expect(url, contains('/avataaars/png'));
      expect(url, contains('size=128'));
    });

    test('portraitFor returns a DiceBear URL', () {
      final url = AvatarGenerator.portraitFor('user-123', variantIndex: 0);
      expect(url, startsWith('https://api.dicebear.com/'));
      expect(url, contains('/png?'));
    });

    test('portraitFor rotates through all styles without throwing', () {
      final count = AvatarGenerator.portraitStyleCount;
      expect(count, greaterThan(0));
      for (int i = 0; i < count; i++) {
        final url =
            AvatarGenerator.portraitFor('user-$i', variantIndex: i, seed: i);
        expect(url, isNotEmpty);
        expect(url, startsWith('https://api.dicebear.com/'));
      }
    });

    test('portraitFor variantIndex wraps around correctly', () {
      final count = AvatarGenerator.portraitStyleCount;
      final url1 = AvatarGenerator.portraitFor('u', variantIndex: 0, seed: 1);
      final url2 = AvatarGenerator.portraitFor(
          'u', variantIndex: count, seed: 1);
      expect(url1, equals(url2));
    });

    test('defaultFor is deterministic for the same userId', () {
      final url1 = AvatarGenerator.defaultFor('user-42');
      final url2 = AvatarGenerator.defaultFor('user-42');
      expect(url1, equals(url2));
    });

    test('defaultFor produces different URLs for different userIds', () {
      final url1 = AvatarGenerator.defaultFor('user-1');
      final url2 = AvatarGenerator.defaultFor('user-2');
      expect(url1, isNot(equals(url2)));
    });

    test('no pollinations.ai URLs are generated', () {
      for (int i = 0; i < AvatarGenerator.portraitStyleCount; i++) {
        final url =
            AvatarGenerator.portraitFor('user', variantIndex: i, seed: 0);
        expect(url, isNot(contains('pollinations')));
      }
      expect(AvatarGenerator.defaultFor('user'),
          isNot(contains('pollinations')));
    });
  });
}
