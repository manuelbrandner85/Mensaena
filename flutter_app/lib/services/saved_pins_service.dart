/// SKILL: mensaena-features
/// Saved-Pins-Service (F64): User-Pins auf der Map. On-device in
/// flutter_secure_storage, kein DB-Hit. Pinning per Long-Press auf Map.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedPin {
  const SavedPin({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  final String id;
  final String label;
  final double lat;
  final double lng;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavedPin.fromJson(Map<String, dynamic> j) => SavedPin(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class SavedPinsService {
  const SavedPinsService._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mensaena_saved_pins_v1';
  static const _maxPins = 50;

  static Future<List<SavedPin>> all() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(SavedPin.fromJson).toList();
    } catch (e) {
      debugPrint('[SavedPins] load failed: $e');
      return [];
    }
  }

  static Future<void> add(SavedPin pin) async {
    final list = await all();
    list.insert(0, pin);
    if (list.length > _maxPins) list.removeRange(_maxPins, list.length);
    await _save(list);
  }

  static Future<void> remove(String id) async {
    final list = await all();
    list.removeWhere((p) => p.id == id);
    await _save(list);
  }

  static Future<void> _save(List<SavedPin> list) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(list.map((p) => p.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[SavedPins] save failed: $e');
    }
  }
}
