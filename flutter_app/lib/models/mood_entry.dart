/// SKILL: mensaena-features
/// Mood-Tracker Model + DB-Mapping.
library;

class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.userId,
    required this.moodLevel,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String userId;
  /// 1=😢 2=😟 3=😐 4=🙂 5=😄
  final int moodLevel;
  final String? note;
  final DateTime createdAt;

  String get emoji {
    switch (moodLevel) {
      case 1:
        return '😢';
      case 2:
        return '😟';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        moodLevel: (j['mood_level'] as num).toInt(),
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
