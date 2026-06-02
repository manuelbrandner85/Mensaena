/// SKILL: mensaena-features + supabase
/// Repositories für Phase-2-12 Mega-Features. Konsolidiert in einer Datei
/// um Datei-Sprawl zu vermeiden — jede Klasse ist eine eigenständige Unit.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/mega_models.dart';
import '../services/supabase_service.dart';

// ── F37 Profile-Views ──────────────────────────────────────────────────

class ProfileViewsRepository {
  const ProfileViewsRepository._();

  static Future<void> recordView(String viewedUserId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == viewedUserId) return;
    try {
      // 1 view pro Tag pro Viewer — debounced via DB-Lookup
      final today =
          DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final existing = await sb
          .from('profile_views')
          .select('id')
          .eq('viewer_id', uid)
          .eq('viewed_id', viewedUserId)
          .gte('created_at', today.toIso8601String())
          .limit(1);
      if ((existing as List).isNotEmpty) return;
      await sb.from('profile_views').insert(
          {'viewer_id': uid, 'viewed_id': viewedUserId});
    } catch (e) {
      debugPrint('[ProfileViews] $e');
    }
  }

  /// Anzahl der Profil-Besuche der letzten 7 Tage (auf eigenes Profil).
  static Future<int> myWeeklyViews() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return 0;
    try {
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final rows = await sb
          .from('profile_views')
          .select('id')
          .eq('viewed_id', uid)
          .gte('created_at', since);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}

// ── F47 Daily-Challenges ───────────────────────────────────────────────

class DailyChallengesRepository {
  const DailyChallengesRepository._();

  static const _pool = [
    ('comment_post', 'Kommentiere einen Beitrag', 5),
    ('help_someone', 'Hilf einem Nachbarn', 10),
    ('share_post', 'Teile einen Beitrag', 3),
    ('rate_interaction', 'Bewerte eine Hilfe', 5),
    ('create_post', 'Erstelle einen Beitrag', 7),
    ('join_event', 'Tritt einem Event bei', 5),
    ('send_thanks', 'Sende eine Danke-Karte', 5),
  ];

  static Future<List<DailyChallenge>> todayChallenges() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      var rows = await sb
          .from('daily_challenges')
          .select()
          .eq('user_id', uid)
          .eq('date', dateStr);
      if ((rows as List).isEmpty) {
        // Generiere 3 zufällige Challenges
        final seed = today.day * 31 + today.month * 17;
        final shuffled = List.of(_pool)
          ..sort((a, b) => ((a.$1.hashCode + seed) %
                  100)
              .compareTo((b.$1.hashCode + seed) % 100));
        final selected = shuffled.take(3);
        await sb.from('daily_challenges').insert(selected
            .map((c) => {
                  'user_id': uid,
                  'challenge_type': c.$1,
                  'challenge_text': c.$2,
                  'karma_reward': c.$3,
                  'date': dateStr,
                })
            .toList());
        rows = await sb
            .from('daily_challenges')
            .select()
            .eq('user_id', uid)
            .eq('date', dateStr);
      }
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(DailyChallenge.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[DailyChallenges] $e');
      return const [];
    }
  }

  /// Schließt die Tages-Challenge ab UND schreibt das Karma gut. Vorher
  /// wurde nur is_completed gesetzt → das angezeigte '+X Karma' war fiktiv.
  /// Gibt das tatsächlich vergebene Karma zurück (0 wenn bereits erledigt).
  static Future<int> markCompleted(String challengeId) async {
    try {
      final res = await sb.rpc<dynamic>('complete_daily_challenge',
          params: {'p_id': challengeId});
      if (res is int) return res;
      if (res is num) return res.toInt();
      return int.tryParse('$res') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

// ── F71 Thank-You-Cards ────────────────────────────────────────────────

class ThankYouCardsRepository {
  const ThankYouCardsRepository._();

  static Future<bool> send({
    required String receiverId,
    int designId = 1,
    String? message,
    String? interactionId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == receiverId) return false;
    try {
      await sb.from('thank_you_cards').insert({
        'sender_id': uid,
        'receiver_id': receiverId,
        'design_id': designId,
        if (message != null && message.isNotEmpty) 'message': message,
        if (interactionId != null) 'interaction_id': interactionId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<ThankYouCard>> received() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('thank_you_cards')
          .select(
              'id, sender_id, receiver_id, interaction_id, design_id, message, created_at, sender:profiles!thank_you_cards_sender_id_fkey(display_name, avatar_url)')
          .eq('receiver_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(ThankYouCard.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

// ── F72 Community-Polls ────────────────────────────────────────────────

class CommunityPollsRepository {
  const CommunityPollsRepository._();

  static Future<List<CommunityPoll>> listActive() async {
    try {
      final rows = await sb
          .from('community_polls')
          .select(
              'id, creator_id, question, options, is_anonymous, closes_at, status, created_at, creator:profiles!community_polls_creator_id_fkey(display_name)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(CommunityPoll.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> vote(String pollId, int optionIndex) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('community_poll_votes').insert({
        'poll_id': pollId,
        'user_id': uid,
        'option_index': optionIndex,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<int, int>> voteCounts(String pollId) async {
    try {
      final rows = await sb
          .from('community_poll_votes')
          .select('option_index')
          .eq('poll_id', pollId);
      final out = <int, int>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final idx = (r['option_index'] as num).toInt();
        out[idx] = (out[idx] ?? 0) + 1;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<int?> myVote(String pollId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('community_poll_votes')
          .select('option_index')
          .eq('poll_id', pollId)
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return (row['option_index'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> create({
    required String question,
    required List<String> options,
    bool isAnonymous = false,
    DateTime? closesAt,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || options.length < 2) return false;
    try {
      await sb.from('community_polls').insert({
        'creator_id': uid,
        'question': question,
        'options': options,
        'is_anonymous': isAnonymous,
        if (closesAt != null) 'closes_at': closesAt.toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── F59 Stories ────────────────────────────────────────────────────────

class StoriesRepository {
  const StoriesRepository._();

  static Future<List<Story>> active() async {
    try {
      final rows = await sb
          .from('stories')
          .select(
              'id, user_id, media_url, media_type, text_overlay, expires_at, view_count, created_at, author:profiles!stories_user_id_fkey(display_name, avatar_url)')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(Story.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> create({
    required String mediaUrl,
    String mediaType = 'image',
    String? textOverlay,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('stories').insert({
        'user_id': uid,
        'media_url': mediaUrl,
        'media_type': mediaType,
        if (textOverlay != null && textOverlay.isNotEmpty)
          'text_overlay': textOverlay,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> recordView(String storyId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('story_views')
          .insert({'story_id': storyId, 'viewer_id': uid});
    } catch (_) {
      // Duplikat ist ok
    }
  }
}

// ── F69 Mentorships ────────────────────────────────────────────────────

class MentorshipsRepository {
  const MentorshipsRepository._();

  static Future<List<Mentorship>> mine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('mentorships')
          .select()
          .or('mentor_id.eq.$uid,mentee_id.eq.$uid')
          .order('started_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(Mentorship.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> request(String mentorId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == mentorId) return false;
    try {
      await sb
          .from('mentorships')
          .insert({'mentor_id': mentorId, 'mentee_id': uid});
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── F16 Livestream-Messages ────────────────────────────────────────────

class LivestreamMessagesRepository {
  const LivestreamMessagesRepository._();

  static Stream<List<LivestreamMessage>> watch(String roomId) {
    return sb
        .from('livestream_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows
            .cast<Map<String, dynamic>>()
            .map(LivestreamMessage.fromJson)
            .toList());
  }

  static Future<bool> send({
    required String roomId,
    required String content,
    String type = 'text',
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('livestream_messages').insert({
        'room_id': roomId,
        'user_id': uid,
        'content': content,
        'type': type,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── F84 Livestream-Gifts ───────────────────────────────────────────────

class LivestreamGiftsRepository {
  const LivestreamGiftsRepository._();

  static Future<bool> send({
    required String roomId,
    required String giftType, // applause|star|diamond
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final cost = giftType == 'diamond'
        ? 20
        : giftType == 'star'
            ? 5
            : 1;
    try {
      await sb.from('livestream_gifts').insert({
        'room_id': roomId,
        'sender_id': uid,
        'gift_type': giftType,
        'karma_cost': cost,
      });
      return true;
    } catch (e) {
      debugPrint('[Gifts] $e');
      return false;
    }
  }

  /// Realtime-Stream der Gifts (für Animation).
  static Stream<List<Map<String, dynamic>>> watch(String roomId) {
    return sb
        .from('livestream_gifts')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }
}

// ── Leaderboard (F46) ──────────────────────────────────────────────────

class LeaderboardRepository {
  const LeaderboardRepository._();

  /// Top 10 nach karma_points (weekly approximation via order).
  static Future<List<Map<String, dynamic>>> topThisWeek({int limit = 10}) async {
    try {
      final rows = await sb
          .from('profiles')
          .select('id, display_name, name, avatar_url, karma_points, trust_score')
          .order('karma_points', ascending: false)
          .limit(limit);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }
}
