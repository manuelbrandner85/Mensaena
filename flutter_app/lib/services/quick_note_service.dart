/// SKILL: mensaena-features
/// Quick-Note-Service (F45): single text-only "Sticky Note" pro User,
/// persistiert on-device in flutter_secure_storage.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class QuickNoteService {
  const QuickNoteService._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mensaena_quick_note_v1';
  static const _maxChars = 1000;

  static Future<String> read() async {
    try {
      return (await _storage.read(key: _key)) ?? '';
    } catch (e) {
      debugPrint('[QuickNote] read failed: $e');
      return '';
    }
  }

  static Future<void> write(String value) async {
    final v = value.length > _maxChars
        ? value.substring(0, _maxChars)
        : value;
    try {
      await _storage.write(key: _key, value: v);
    } catch (e) {
      debugPrint('[QuickNote] write failed: $e');
    }
  }
}
