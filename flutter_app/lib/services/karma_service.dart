/// SKILL: mensaena-features + supabase
/// Karma-Service (F31): berechnet Karma-Punkte aus echten Tabellen.
///
/// Punkte:
///   +5  pro abgeschlossene Hilfe als helper (interactions.status=completed)
///   +3  pro Post (posts wo user_id = uid)
///   +2  pro Trust-Rating ≥ 4 erhalten (trust_ratings.rated_id = uid)
///   +1  pro Kommentar (post_comments wo user_id = uid)
///
/// Level-Schwellen:
///   0–9      Nachbar:in
///   10–29    Helfer:in
///   30–79    Stütze
///   80–199   Anker
///   200+     Leuchtturm
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

class KarmaSnapshot {
  const KarmaSnapshot({
    required this.points,
    required this.helps,
    required this.posts,
    required this.ratings,
    required this.comments,
  });

  final int points;
  final int helps;
  final int posts;
  final int ratings;
  final int comments;

  KarmaLevel get level => KarmaLevel.forPoints(points);

  /// Punkte bis zum naechsten Level. 0 wenn Max.
  int get pointsToNext {
    final next = level.nextThreshold;
    if (next == null) return 0;
    return next - points;
  }

  /// Progress 0..1 innerhalb des aktuellen Levels.
  double get progressInLevel {
    final start = level.threshold;
    final next = level.nextThreshold;
    if (next == null) return 1.0;
    final span = next - start;
    if (span <= 0) return 1.0;
    return ((points - start) / span).clamp(0.0, 1.0);
  }
}

enum KarmaLevel {
  neighbor(0, 'karma.levels.neighbor'),
  helper(10, 'karma.levels.helper'),
  pillar(30, 'karma.levels.pillar'),
  anchor(80, 'karma.levels.anchor'),
  beacon(200, 'karma.levels.beacon');

  const KarmaLevel(this.threshold, this.labelKey);

  final int threshold;
  final String labelKey;

  int? get nextThreshold {
    final idx = KarmaLevel.values.indexOf(this);
    if (idx >= KarmaLevel.values.length - 1) return null;
    return KarmaLevel.values[idx + 1].threshold;
  }

  static KarmaLevel forPoints(int p) {
    KarmaLevel result = KarmaLevel.neighbor;
    for (final l in KarmaLevel.values) {
      if (p >= l.threshold) result = l;
    }
    return result;
  }
}

class KarmaService {
  const KarmaService._();

  static Future<KarmaSnapshot> compute() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      return const KarmaSnapshot(
          points: 0, helps: 0, posts: 0, ratings: 0, comments: 0);
    }
    int helps = 0, posts = 0, ratings = 0, comments = 0;
    try {
      final h = await sb
          .from('interactions')
          .select('id')
          .eq('helper_id', uid)
          .eq('status', 'completed');
      helps = (h as List).length;
    } catch (e) {
      debugPrint('[Karma] helps query failed: $e');
    }
    try {
      final p = await sb.from('posts').select('id').eq('user_id', uid);
      posts = (p as List).length;
    } catch (e) {
      debugPrint('[Karma] posts query failed: $e');
    }
    try {
      final r = await sb
          .from('trust_ratings')
          .select('rating')
          .eq('rated_id', uid)
          .gte('rating', 4);
      ratings = (r as List).length;
    } catch (e) {
      debugPrint('[Karma] ratings query failed: $e');
    }
    try {
      final c = await sb.from('post_comments').select('id').eq('user_id', uid);
      comments = (c as List).length;
    } catch (e) {
      debugPrint('[Karma] comments query failed: $e');
    }
    final points = helps * 5 + posts * 3 + ratings * 2 + comments;
    return KarmaSnapshot(
      points: points,
      helps: helps,
      posts: posts,
      ratings: ratings,
      comments: comments,
    );
  }
}
