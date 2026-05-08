import 'package:flutter/material.dart';

enum ChallengeDifficulty {
  easy,
  medium,
  hard;

  static ChallengeDifficulty fromString(String? raw) {
    switch (raw) {
      case 'easy':
        return ChallengeDifficulty.easy;
      case 'hard':
        return ChallengeDifficulty.hard;
      default:
        return ChallengeDifficulty.medium;
    }
  }

  String get label {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 'Leicht';
      case ChallengeDifficulty.medium:
        return 'Mittel';
      case ChallengeDifficulty.hard:
        return 'Schwer';
    }
  }

  Color get color {
    switch (this) {
      case ChallengeDifficulty.easy:
        return const Color(0xFF15803D);
      case ChallengeDifficulty.medium:
        return const Color(0xFFD97706);
      case ChallengeDifficulty.hard:
        return const Color(0xFFB91C1C);
    }
  }
}

class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.points,
    required this.participantCount,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.creatorId,
    this.description,
    this.maxParticipants,
  });

  final String id;
  final String title;
  final String category;
  final ChallengeDifficulty difficulty;
  final int points;
  final int participantCount;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;
  final String creatorId;
  final String? description;
  final int? maxParticipants;

  bool get isActive {
    final now = DateTime.now();
    return status == 'active' &&
        now.isAfter(startDate.subtract(const Duration(hours: 1))) &&
        now.isBefore(endDate);
  }

  factory Challenge.fromJson(Map<String, dynamic> j) {
    return Challenge(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      category: j['category'] as String? ?? 'general',
      difficulty: ChallengeDifficulty.fromString(j['difficulty'] as String?),
      points: (j['points'] as num?)?.toInt() ?? 0,
      participantCount: (j['participant_count'] as num?)?.toInt() ?? 0,
      startDate: DateTime.tryParse(j['start_date'] as String? ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(j['end_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      status: j['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      creatorId: j['creator_id'] as String? ?? '',
      description: j['description'] as String?,
      maxParticipants: (j['max_participants'] as num?)?.toInt(),
    );
  }
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.challengeId,
    required this.userId,
    required this.checkins,
    required this.lastCheckinDate,
  });

  final String challengeId;
  final String userId;
  final int checkins;
  final DateTime? lastCheckinDate;
}
