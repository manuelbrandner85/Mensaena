import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/models/challenge_progress.dart';

void main() {
  group('ChallengeProgress.fromJson', () {
    test('mappt alle Felder korrekt', () {
      final p = ChallengeProgress.fromJson({
        'id': 'p1',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'status': 'active',
        'progress_pct': 42,
        'completed_at': null,
        'joined_at': '2026-06-01T10:00:00Z',
        'checked_in': false,
      });

      expect(p.id, 'p1');
      expect(p.challengeId, 'c1');
      expect(p.userId, 'u1');
      expect(p.status, 'active');
      expect(p.progressPct, 42);
      expect(p.completed, isFalse);
      expect(p.joinedAt, isNotNull);
      expect(p.checkedIn, isFalse);
    });

    test('completed=true wenn status=completed', () {
      final p = ChallengeProgress.fromJson({
        'id': 'p2',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'status': 'completed',
        'progress_pct': 100,
        'completed_at': '2026-06-16T12:00:00Z',
        'joined_at': null,
        'checked_in': false,
      });

      expect(p.completed, isTrue);
      expect(p.progressPct, 100);
      expect(p.completedAt, isNotNull);
    });

    test('completed=true wenn completedAt gesetzt, auch ohne status=completed',
        () {
      final p = ChallengeProgress.fromJson({
        'id': 'p3',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'status': 'active',
        'progress_pct': 100,
        'completed_at': '2026-06-16T12:00:00Z',
        'joined_at': null,
        'checked_in': false,
      });

      expect(p.completed, isTrue);
    });

    test('fehlende optionale Felder werden auf Defaults gesetzt', () {
      final p = ChallengeProgress.fromJson({
        'id': 'p4',
        'challenge_id': 'c2',
        'user_id': 'u2',
      });

      expect(p.status, 'active');
      expect(p.progressPct, 0);
      expect(p.completed, isFalse);
      expect(p.checkedIn, isFalse);
    });

    test('currentCount gibt progressPct zurück', () {
      final p = ChallengeProgress.fromJson({
        'id': 'p5',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'progress_pct': 75,
      });

      expect(p.currentCount, 75);
    });
  });
}
