/// SKILL: mensaena-features
/// HealthTipsService — Tages-Gesundheitstipp aus lokalem Asset.
///
/// Asset: assets/data/health_tips.json — kuratierte Liste von Tipps
/// (Mensaena-eigen, kein API). Tagesindex = (DayOfYear - 1) % length,
/// rotiert sich also pro Jahr durch.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

enum HealthTipCategory { ernaehrung, bewegung, mental, schlaf, vorsorge }

class HealthTip {
  const HealthTip({
    required this.text,
    required this.category,
  });
  final String text;
  final HealthTipCategory category;
}

class HealthTipsService {
  const HealthTipsService._();

  static List<HealthTip>? _cache;

  /// Liefert den Tipp des aktuellen Tages. Laedt das Asset lazy beim
  /// ersten Aufruf und cached es im Memory.
  static Future<HealthTip?> tipForToday({DateTime? now}) async {
    final tips = await _load();
    if (tips.isEmpty) return null;
    final n = now ?? DateTime.now();
    final dayOfYear = int.parse(
        DateTime(n.year, n.month, n.day).difference(DateTime(n.year)).inDays.toString());
    final idx = dayOfYear % tips.length;
    return tips[idx];
  }

  static Future<List<HealthTip>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/health_tips.json');
      final j = jsonDecode(raw) as List;
      _cache = j.map((e) {
        final m = e as Map<String, dynamic>;
        return HealthTip(
          text: m['text'] as String? ?? '',
          category: _parseCategory(m['category'] as String?),
        );
      }).where((t) => t.text.isNotEmpty).toList();
      return _cache!;
    } catch (_) {
      _cache = const <HealthTip>[];
      return _cache!;
    }
  }

  static HealthTipCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'bewegung':
        return HealthTipCategory.bewegung;
      case 'mental':
        return HealthTipCategory.mental;
      case 'schlaf':
        return HealthTipCategory.schlaf;
      case 'vorsorge':
        return HealthTipCategory.vorsorge;
      case 'ernaehrung':
      default:
        return HealthTipCategory.ernaehrung;
    }
  }
}
