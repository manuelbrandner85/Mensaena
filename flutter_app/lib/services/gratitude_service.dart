/// SKILL: mensaena-features
/// Gratitude-Service (F30): on-device Dankbarkeits-Tagebuch.
/// Persistiert eine Liste von Eintraegen (date, text) in
/// flutter_secure_storage als JSON-Array.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GratitudeEntry {
  const GratitudeEntry({required this.date, required this.text});

  /// YYYY-MM-DD
  final String date;
  final String text;

  Map<String, dynamic> toJson() => {'date': date, 'text': text};

  factory GratitudeEntry.fromJson(Map<String, dynamic> j) =>
      GratitudeEntry(date: j['date'] as String, text: j['text'] as String);
}

class GratitudeService {
  const GratitudeService._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mensaena_gratitude_entries_v1';
  static const _maxEntries = 365;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<List<GratitudeEntry>> all() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(GratitudeEntry.fromJson).toList();
    } catch (e) {
      debugPrint('[Gratitude] load failed: $e');
      return [];
    }
  }

  static Future<GratitudeEntry?> today() async {
    final t = _today();
    final entries = await all();
    for (final e in entries) {
      if (e.date == t) return e;
    }
    return null;
  }

  static Future<void> setToday(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final entries = await all();
    final t = _today();
    final filtered = entries.where((e) => e.date != t).toList();
    filtered.insert(0, GratitudeEntry(date: t, text: trimmed));
    if (filtered.length > _maxEntries) {
      filtered.removeRange(_maxEntries, filtered.length);
    }
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(filtered.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[Gratitude] save failed: $e');
    }
  }

  static Future<void> deleteFor(String date) async {
    final entries = await all();
    final filtered = entries.where((e) => e.date != date).toList();
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(filtered.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
