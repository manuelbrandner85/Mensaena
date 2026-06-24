import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isTransientAuthNetworkError', () {
    test('erkennt AuthRetryableFetchException als transient', () {
      final err = AuthRetryableFetchException(
        message: 'Failed host lookup',
        statusCode: '503',
      );
      expect(isTransientAuthNetworkError(err), isTrue);
    });

    test('erkennt SocketException als transient', () {
      const err = SocketException('Connection reset by peer');
      expect(isTransientAuthNetworkError(err), isTrue);
    });

    test('echte App-Fehler gelten NICHT als transient', () {
      expect(isTransientAuthNetworkError(StateError('boom')), isFalse);
      expect(isTransientAuthNetworkError(ArgumentError('bad')), isFalse);
      expect(
        isTransientAuthNetworkError(const FormatException('nope')),
        isFalse,
      );
    });

    test('handleAuthStreamError wirft nie — auch bei unerwarteten Fehlern', () {
      expect(
        () => handleAuthStreamError(StateError('unexpected')),
        returnsNormally,
      );
      expect(
        () => handleAuthStreamError(const SocketException('offline')),
        returnsNormally,
      );
    });
  });
}
