/// SKILL: mensaena-features — Wave-Final Repositories
/// account_deletion_requests, user_streaks, karma_log, stream_clips,
/// event_checkins, crash_logs
library;

import '../services/supabase_service.dart';

class AccountDeletionRepository {
  Future<Map<String, dynamic>?> current() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    final rows = await sb
        .from('account_deletion_requests')
        .select()
        .eq('user_id', uid)
        .eq('cancelled', false)
        .limit(1);
    final list = (rows as List).whereType<Map<String, dynamic>>().toList();
    return list.isEmpty ? null : list.first;
  }

  Future<void> request({String? reason}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await sb.from('account_deletion_requests').upsert({
      'user_id': uid,
      'reason': reason,
      'cancelled': false,
      'requested_at': DateTime.now().toIso8601String(),
      'scheduled_for':
          DateTime.now().add(const Duration(days: 14)).toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> cancel() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await sb
        .from('account_deletion_requests')
        .update({'cancelled': true})
        .eq('user_id', uid);
  }
}

class UserStreaksRepository {
  Future<Map<String, dynamic>?> current() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    final rows = await sb
        .from('user_streaks')
        .select()
        .eq('user_id', uid)
        .limit(1);
    final list = (rows as List).whereType<Map<String, dynamic>>().toList();
    return list.isEmpty ? null : list.first;
  }

  /// Ruft auf jedem App-Launch — bumpt Streak wenn neuer Tag.
  Future<void> tickActivity() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    final today = DateTime.now().toUtc();
    final todayDate =
        DateTime.utc(today.year, today.month, today.day).toIso8601String().substring(0, 10);
    try {
      final existing = await current();
      if (existing == null) {
        await sb.from('user_streaks').insert({
          'user_id': uid,
          'current_streak': 1,
          'longest_streak': 1,
          'last_active_date': todayDate,
        });
        return;
      }
      final lastStr = existing['last_active_date'] as String?;
      if (lastStr == todayDate) return;
      final last = lastStr != null ? DateTime.tryParse(lastStr)?.toUtc() : null;
      final yesterday = DateTime.utc(today.year, today.month, today.day)
          .subtract(const Duration(days: 1));
      final cur = (existing['current_streak'] as int?) ?? 0;
      final longest = (existing['longest_streak'] as int?) ?? 0;
      final newCur = (last != null &&
              last.year == yesterday.year &&
              last.month == yesterday.month &&
              last.day == yesterday.day)
          ? cur + 1
          : 1;
      await sb.from('user_streaks').update({
        'current_streak': newCur,
        'longest_streak': newCur > longest ? newCur : longest,
        'last_active_date': todayDate,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', uid);
    } catch (_) {}
  }
}

class KarmaLogRepository {
  Future<List<Map<String, dynamic>>> recent({int limit = 50}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    final rows = await sb
        .from('karma_log')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> add({
    required int delta,
    required String reason,
    String? referenceType,
    String? referenceId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('karma_log').insert({
        'user_id': uid,
        'delta': delta,
        'reason': reason,
        'reference_type': referenceType,
        'reference_id': referenceId,
      });
    } catch (_) {}
  }
}

class EventCheckinsRepository {
  Future<bool> checkIn(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_checkins').insert({
        'event_id': eventId,
        'user_id': uid,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> count(String eventId) async {
    try {
      final rows = await sb
          .from('event_checkins')
          .select('user_id')
          .eq('event_id', eventId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> hasCheckedIn(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await sb
          .from('event_checkins')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

class StreamClipsRepository {
  Future<List<Map<String, dynamic>>> forStream(String streamId) async {
    try {
      final rows = await sb
          .from('stream_clips')
          .select()
          .eq('stream_id', streamId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> create({
    required String streamId,
    required int startSeconds,
    int durationSeconds = 30,
    String? title,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('stream_clips').insert({
        'stream_id': streamId,
        'user_id': uid,
        'start_seconds': startSeconds,
        'duration_seconds': durationSeconds,
        'title': title,
      });
    } catch (_) {}
  }
}

