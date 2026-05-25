/// SKILL: mensaena-features + supabase
/// Mood-Tracker Repository.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/mood_entry.dart';
import '../services/supabase_service.dart';

class MoodRepository {
  const MoodRepository._();

  static Future<MoodEntry?> log({
    required int level,
    String? note,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('mood_entries')
          .insert({
            'user_id': uid,
            'mood_level': level,
            if (note != null && note.isNotEmpty) 'note': note,
          })
          .select()
          .single();
      return MoodEntry.fromJson(row);
    } catch (e) {
      debugPrint('[MoodRepo] log failed: $e');
      return null;
    }
  }

  static Future<List<MoodEntry>> history({int limit = 30}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('mood_entries')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(MoodEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[MoodRepo] history failed: $e');
      return const [];
    }
  }

  /// True wenn der User heute schon einen Eintrag gemacht hat.
  static Future<bool> hasLoggedToday() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return true; // anonym → kein nervender Dialog
    try {
      final now = DateTime.now().toUtc();
      final startOfDay =
          DateTime.utc(now.year, now.month, now.day).toIso8601String();
      final rows = await sb
          .from('mood_entries')
          .select('id')
          .eq('user_id', uid)
          .gte('created_at', startOfDay)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return true; // im Zweifel nicht nerven
    }
  }

  /// Letzte 7 Tage als kompakte Liste (1 Wert/Tag, oder null wenn nichts).
  /// Index 0 = heute, 6 = vor 6 Tagen.
  static Future<List<double?>> last7Days() async {
    final entries = await history(limit: 50);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = List<double?>.filled(7, null);
    final byDay = <int, List<int>>{};
    for (final e in entries) {
      final local = e.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff > 6) continue;
      byDay.putIfAbsent(diff, () => []).add(e.moodLevel);
    }
    for (final entry in byDay.entries) {
      final values = entry.value;
      if (values.isEmpty) continue;
      final avg = values.reduce((a, b) => a + b) / values.length;
      result[entry.key] = avg;
    }
    return result;
  }

  /// True wenn der User die letzten 3 Tage jeweils mood ≤ 2 hatte.
  /// Auslöser für Telefonseelsorge-Hinweis.
  static Future<bool> hasNegativeStreak() async {
    final days = await last7Days();
    if (days.length < 3) return false;
    int negDays = 0;
    for (int i = 0; i < 3; i++) {
      final v = days[i];
      if (v != null && v <= 2.0) negDays++;
    }
    return negDays >= 3;
  }
}
