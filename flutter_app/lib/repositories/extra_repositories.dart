/// SKILL: mensaena-features + supabase
/// Extra-Repositories — alle bisher ungenutzten Supabase-Tabellen.
/// Foundation für künftige UI-Integration. Jede Klasse exponiert die
/// Basis-Operationen (list/get/create/delete/toggle) gegen die jeweilige
/// Tabelle. Models sind als Map<String,dynamic> zurückgegeben, sodass
/// UI flexibel auf die Felder zugreifen kann ohne Boilerplate-Modelle.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../services/supabase_service.dart';

// ─── Post-Features ────────────────────────────────────────────────────

/// post_reactions — Emoji-Reactions auf Posts (nicht zu verwechseln mit
/// post_votes Up/Down). Spalten: post_id, user_id, reaction_type, created_at.
class PostReactionsRepository {
  const PostReactionsRepository._();

  static Future<List<Map<String, dynamic>>> forPost(String postId) async {
    try {
      final rows = await sb
          .from('post_reactions')
          .select('id, user_id, reaction_type, created_at')
          .eq('post_id', postId);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Toggle: setzt Reaction oder entfernt existierende (gleicher type).
  /// Bei anderem type wird der alte type ersetzt (1 Reaction pro User/Post).
  static Future<bool> toggle(String postId, String reactionType) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('post_reactions')
          .select('id, reaction_type')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          await sb
              .from('post_reactions')
              .delete()
              .eq('id', existing['id'] as Object);
          return false;
        }
        await sb
            .from('post_reactions')
            .update({'reaction_type': reactionType}).eq(
                'id', existing['id'] as Object);
        return true;
      }
      await sb.from('post_reactions').insert({
        'post_id': postId,
        'user_id': uid,
        'reaction_type': reactionType,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// post_tags — Frei vergebene Tags auf Posts.
class PostTagsRepository {
  const PostTagsRepository._();

  static Future<List<String>> forPost(String postId) async {
    try {
      final rows = await sb
          .from('post_tags')
          .select('tag')
          .eq('post_id', postId);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['tag'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> setTags(String postId, List<String> tags) async {
    try {
      await sb.from('post_tags').delete().eq('post_id', postId);
      if (tags.isEmpty) return true;
      await sb.from('post_tags').insert(tags
          .map((t) => {'post_id': postId, 'tag': t.toLowerCase().trim()})
          .toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// followed_tags — D2: User folgt einzelnen Tags, um den Feed zu kuratieren.
class FollowedTagsRepository {
  const FollowedTagsRepository._();

  static Future<List<String>> myTags() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('followed_tags')
          .select('tag')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => (r['tag'] as String?) ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> isFollowed(String tag) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final t = tag.toLowerCase().trim();
    try {
      final rows = await sb
          .from('followed_tags')
          .select('id')
          .eq('user_id', uid)
          .eq('tag', t)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the new state (true = jetzt gefolgt).
  static Future<bool> toggleFollow(String tag) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final t = tag.toLowerCase().trim();
    if (t.isEmpty) return false;
    final currently = await isFollowed(t);
    try {
      if (currently) {
        await sb
            .from('followed_tags')
            .delete()
            .eq('user_id', uid)
            .eq('tag', t);
        return false;
      }
      await sb.from('followed_tags').insert({
        'user_id': uid,
        'tag': t,
      });
      return true;
    } catch (_) {
      return currently;
    }
  }
}

/// post_drafts — Speichere unfertige Posts für später (1 Draft/User).
class PostDraftsRepository {
  const PostDraftsRepository._();

  static Future<Map<String, dynamic>?> myDraft() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('post_drafts')
          .select('draft_data, updated_at')
          .eq('user_id', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> save(Map<String, dynamic> draftData) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('post_drafts').upsert({
        'user_id': uid,
        'draft_data': draftData,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clear() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('post_drafts').delete().eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// post_templates — Vorgefertigte Post-Vorlagen (admin-kuratiert).
class PostTemplatesRepository {
  const PostTemplatesRepository._();

  static Future<List<Map<String, dynamic>>> listActive() async {
    try {
      final rows = await sb
          .from('post_templates')
          .select()
          .eq('is_active', true)
          .order('category')
          .limit(60);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

// ─── Organization-Features ────────────────────────────────────────────

/// organization_reviews — Bewertungen für Organisationen (1-5 Sterne).
class OrganizationReviewsRepository {
  const OrganizationReviewsRepository._();

  static Future<List<Map<String, dynamic>>> forOrg(String orgId) async {
    try {
      final rows = await sb
          .from('organization_reviews')
          .select(
              'id, user_id, rating, title, content, helpful_count, admin_response, created_at, profiles!organization_reviews_user_id_fkey(name, display_name, avatar_url)')
          .eq('organization_id', orgId)
          .eq('is_flagged', false)
          .order('helpful_count', ascending: false)
          .limit(50);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> create({
    required String orgId,
    required int rating,
    String? title,
    String? content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    if (rating < 1 || rating > 5) return false;
    try {
      await sb.from('organization_reviews').insert({
        'organization_id': orgId,
        'user_id': uid,
        'rating': rating,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markHelpful(String reviewId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('organization_review_helpful')
          .select('id')
          .eq('review_id', reviewId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('organization_review_helpful')
            .delete()
            .eq('id', existing['id'] as Object);
        return false;
      }
      await sb.from('organization_review_helpful').insert({
        'review_id': reviewId,
        'user_id': uid,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// organization_members — User-Mitgliedschaften in Orgs.
class OrganizationMembersRepository {
  const OrganizationMembersRepository._();

  static Future<List<Map<String, dynamic>>> forOrg(String orgId) async {
    try {
      final rows = await sb
          .from('organization_members')
          .select(
              'id, user_id, role, joined_at, profiles!organization_members_user_id_fkey(name, display_name, avatar_url)')
          .eq('organization_id', orgId)
          .order('joined_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> join(String orgId, {String role = 'member'}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('organization_members').insert({
        'organization_id': orgId,
        'user_id': uid,
        'role': role,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> leave(String orgId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('organization_members')
          .delete()
          .eq('organization_id', orgId)
          .eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// organization_invites — Einladungs-Codes für Org-Beitritt.
class OrganizationInvitesRepository {
  const OrganizationInvitesRepository._();

  static Future<Map<String, dynamic>?> byCode(String code) async {
    try {
      final row = await sb
          .from('organization_invites')
          .select()
          .eq('code', code)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }
}

// ─── Group-Features ───────────────────────────────────────────────────

/// group_post_comments — Kommentare auf Gruppen-Posts.
class GroupPostCommentsRepository {
  const GroupPostCommentsRepository._();

  static Future<List<Map<String, dynamic>>> forPost(String postId) async {
    try {
      final rows = await sb
          .from('group_post_comments')
          .select(
              'id, user_id, content, created_at, profiles!group_post_comments_user_id_fkey(name, display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> add(String postId, String content) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final t = content.trim();
    if (t.isEmpty) return false;
    try {
      await sb.from('group_post_comments').insert({
        'post_id': postId,
        'user_id': uid,
        'content': t,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> delete(String commentId) async {
    try {
      await sb.from('group_post_comments').delete().eq('id', commentId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// group_post_reactions — Emoji-Reactions auf Gruppen-Posts.
class GroupPostReactionsRepository {
  const GroupPostReactionsRepository._();

  static Future<List<Map<String, dynamic>>> forPost(String postId) async {
    try {
      final rows = await sb
          .from('group_post_reactions')
          .select('id, user_id, emoji, created_at')
          .eq('post_id', postId);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> toggle(String postId, String emoji) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('group_post_reactions')
          .select('id, emoji')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        if (existing['emoji'] == emoji) {
          await sb
              .from('group_post_reactions')
              .delete()
              .eq('id', existing['id'] as Object);
          return false;
        }
        await sb
            .from('group_post_reactions')
            .update({'emoji': emoji}).eq('id', existing['id'] as Object);
        return true;
      }
      await sb.from('group_post_reactions').insert({
        'post_id': postId,
        'user_id': uid,
        'emoji': emoji,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// group_invitations — Einladungen in private Gruppen.
class GroupInvitationsRepository {
  const GroupInvitationsRepository._();

  static Future<List<Map<String, dynamic>>> myInvitations() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('group_invitations')
          .select(
              'id, group_id, invited_by, status, created_at, groups(name, avatar_url)')
          .eq('invited_user_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> invite(String groupId, String userId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('group_invitations').insert({
        'group_id': groupId,
        'invited_by': uid,
        'invited_user_id': userId,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> respond(String invitationId, bool accept) async {
    try {
      await sb.from('group_invitations').update({
        'status': accept ? 'accepted' : 'declined',
      }).eq('id', invitationId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Event-Features ───────────────────────────────────────────────────

/// event_rsvps — RSVP (lite, ohne Status — nur Zusage).
class EventRsvpsRepository {
  const EventRsvpsRepository._();

  static Future<bool> toggle(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('event_rsvps')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('event_rsvps')
            .delete()
            .eq('id', existing['id'] as Object);
        return false;
      }
      await sb
          .from('event_rsvps')
          .insert({'event_id': eventId, 'user_id': uid});
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// event_rideshares — Mitfahrgelegenheiten zu Events.
class EventRidesharesRepository {
  const EventRidesharesRepository._();

  static Future<List<Map<String, dynamic>>> forEvent(String eventId) async {
    try {
      final rows = await sb
          .from('event_rideshares')
          .select(
              'id, user_id, role, seats, from_location, departure_time, notes, profiles!event_rideshares_user_id_fkey(name, display_name, avatar_url)')
          .eq('event_id', eventId)
          .order('departure_time');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> offer({
    required String eventId,
    required String role, // 'driver' | 'passenger'
    required int seats,
    required String fromLocation,
    DateTime? departureTime,
    String? notes,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_rideshares').insert({
        'event_id': eventId,
        'user_id': uid,
        'role': role,
        'seats': seats,
        'from_location': fromLocation,
        if (departureTime != null)
          'departure_time': departureTime.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancel(String rideshareId) async {
    try {
      await sb.from('event_rideshares').delete().eq('id', rideshareId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Marketplace-Features ─────────────────────────────────────────────

/// marketplace_messages — Buyer/Seller-Chat zu einem Listing.
class MarketplaceMessagesRepository {
  const MarketplaceMessagesRepository._();

  static Future<List<Map<String, dynamic>>> threadFor(
      String listingId, String otherUserId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('marketplace_messages')
          .select()
          .eq('listing_id', listingId)
          .or('and(sender_id.eq.$uid,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$uid)')
          .order('created_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> send({
    required String listingId,
    required String receiverId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final t = content.trim();
    if (t.isEmpty) return false;
    try {
      await sb.from('marketplace_messages').insert({
        'listing_id': listingId,
        'sender_id': uid,
        'receiver_id': receiverId,
        'content': t,
        'is_read': false,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markRead(String listingId, String senderId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('marketplace_messages')
          .update({'is_read': true})
          .eq('listing_id', listingId)
          .eq('sender_id', senderId)
          .eq('receiver_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// marketplace_reports — Melde fragwürdige Listings.
class MarketplaceReportsRepository {
  const MarketplaceReportsRepository._();

  static Future<bool> report({
    required String listingId,
    required String reason,
    String? details,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('marketplace_reports').insert({
        'listing_id': listingId,
        'reporter_id': uid,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        'status': 'open',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// farm_favorites — Lieblings-Bauernhöfe / Direktvermarkter.
class FarmFavoritesRepository {
  const FarmFavoritesRepository._();

  static Future<Set<String>> myIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await sb
          .from('farm_favorites')
          .select('farm_id')
          .eq('user_id', uid);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['farm_id'] as String)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<bool> toggle(String farmId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('farm_favorites')
          .select('id')
          .eq('user_id', uid)
          .eq('farm_id', farmId)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('farm_favorites')
            .delete()
            .eq('id', existing['id'] as Object);
        return false;
      }
      await sb
          .from('farm_favorites')
          .insert({'user_id': uid, 'farm_id': farmId});
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Channel-Features ─────────────────────────────────────────────────

/// channel_polls — Umfragen in einem Chat-Channel.
class ChannelPollsRepository {
  const ChannelPollsRepository._();

  static Future<List<Map<String, dynamic>>> forChannel(
      String channelId) async {
    try {
      final rows = await sb
          .from('channel_polls')
          .select('id, created_by, question, options, ends_at, created_at')
          .eq('channel_id', channelId)
          .order('created_at', ascending: false)
          .limit(20);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> create({
    required String channelId,
    required String question,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || options.length < 2) return null;
    try {
      final row = await sb
          .from('channel_polls')
          .insert({
            'channel_id': channelId,
            'created_by': uid,
            'question': question.trim(),
            'options': options,
            if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
          })
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// poll_votes — Stimmen auf channel_polls.
class PollVotesRepository {
  const PollVotesRepository._();

  static Future<List<Map<String, dynamic>>> forPoll(String pollId) async {
    try {
      final rows = await sb
          .from('poll_votes')
          .select('id, user_id, option_index, created_at')
          .eq('poll_id', pollId);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> vote(String pollId, int optionIndex) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      // Replace own vote.
      await sb
          .from('poll_votes')
          .delete()
          .eq('poll_id', pollId)
          .eq('user_id', uid);
      await sb.from('poll_votes').insert({
        'poll_id': pollId,
        'user_id': uid,
        'option_index': optionIndex,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// channel_events — Geplante Live-Events in einem Channel.
class ChannelEventsRepository {
  const ChannelEventsRepository._();

  static Future<List<Map<String, dynamic>>> forChannel(
      String channelId) async {
    try {
      final rows = await sb
          .from('channel_events')
          .select()
          .eq('channel_id', channelId)
          .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .order('scheduled_at')
          .limit(20);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> create({
    required String channelId,
    required String title,
    required DateTime scheduledAt,
    String? roomName,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('channel_events').insert({
        'channel_id': channelId,
        'created_by': uid,
        'title': title.trim(),
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (roomName != null) 'room_name': roomName,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Crisis-Features ──────────────────────────────────────────────────

/// crisis_reports — Nutzer melden Krisen / Notfälle.
class CrisisReportsRepository {
  const CrisisReportsRepository._();

  static Future<List<Map<String, dynamic>>> listActive(
      {int limit = 50}) async {
    try {
      final rows = await sb
          .from('crisis_reports')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> report({
    required String title,
    required String description,
    required String type,
    required String severity,
    double? latitude,
    double? longitude,
    String? city,
    String? country,
    String? contactPhone,
    bool isAnonymous = false,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_reports').insert({
        'reporter_id': uid,
        'title': title.trim(),
        'description': description.trim(),
        'type': type,
        'severity': severity,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (contactPhone != null) 'contact_phone': contactPhone,
        'is_anonymous': isAnonymous,
        'status': 'open',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// crisis_resources — Ressourcen-Angebote (Wasser, Decken, Unterkunft).
class CrisisResourcesRepository {
  const CrisisResourcesRepository._();

  static Future<List<Map<String, dynamic>>> forCrisis(
      String crisisId) async {
    try {
      final rows = await sb
          .from('crisis_resources')
          .select()
          .eq('crisis_id', crisisId)
          .eq('status', 'available')
          .order('created_at', ascending: false);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> offer({
    required String crisisId,
    required String resourceType,
    required String title,
    String? description,
    String? quantity,
    String? locationText,
    double? latitude,
    double? longitude,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_resources').insert({
        'crisis_id': crisisId,
        'provider_id': uid,
        'resource_type': resourceType,
        'title': title.trim(),
        if (description != null) 'description': description,
        if (quantity != null) 'quantity': quantity,
        if (locationText != null) 'location_text': locationText,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'status': 'available',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> reserve(String resourceId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_resources').update({
        'status': 'reserved',
        'reserved_by': uid,
      }).eq('id', resourceId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Interactions / Volunteer ─────────────────────────────────────────

/// interaction_updates — Verlauf-Eintraege zu einer Interaktion.
class InteractionUpdatesRepository {
  const InteractionUpdatesRepository._();

  static Future<List<Map<String, dynamic>>> forInteraction(
      String interactionId) async {
    try {
      final rows = await sb
          .from('interaction_updates')
          .select(
              'id, author_id, update_type, content, old_status, new_status, created_at, profiles!interaction_updates_author_id_fkey(name, display_name, avatar_url)')
          .eq('interaction_id', interactionId)
          .order('created_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> add({
    required String interactionId,
    required String updateType,
    String? content,
    String? oldStatus,
    String? newStatus,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('interaction_updates').insert({
        'interaction_id': interactionId,
        'author_id': uid,
        'update_type': updateType,
        if (content != null) 'content': content,
        if (oldStatus != null) 'old_status': oldStatus,
        if (newStatus != null) 'new_status': newStatus,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// volunteer_signups — Anmeldungen zu Helfer-Posts.
class VolunteerSignupsRepository {
  const VolunteerSignupsRepository._();

  static Future<List<Map<String, dynamic>>> forPost(String postId) async {
    try {
      final rows = await sb
          .from('volunteer_signups')
          .select(
              'id, user_id, message, status, created_at, profiles!volunteer_signups_user_id_fkey(name, display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> signup(String postId, {String? message}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('volunteer_signups').insert({
        'post_id': postId,
        'user_id': uid,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> respond(String signupId, String status) async {
    try {
      await sb.from('volunteer_signups').update({
        'status': status,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', signupId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── User & Misc ─────────────────────────────────────────────────────

/// user_status — Custom Status (Slack-style "🚴 Bin radeln").
class UserStatusRepository {
  const UserStatusRepository._();

  static Future<Map<String, dynamic>?> mine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('user_status')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> set(
      {required String status, String? statusText}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('user_status').upsert({
        'user_id': uid,
        'status': status,
        if (statusText != null) 'status_text': statusText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clear() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('user_status').delete().eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// thanks — Dankeschön senden an Nachbar:innen.
class ThanksRepository {
  const ThanksRepository._();

  static Future<List<Map<String, dynamic>>> received() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('thanks')
          .select(
              'id, from_user_id, emoji, message, created_at, profiles!thanks_from_user_id_fkey(name, display_name, avatar_url)')
          .eq('to_user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> send({
    required String toUserId,
    required String emoji,
    String? message,
    String? postId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == toUserId) return false;
    try {
      await sb.from('thanks').insert({
        'from_user_id': uid,
        'to_user_id': toUserId,
        'emoji': emoji,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (postId != null) 'post_id': postId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// regions — Regionen-Listing (public).
class RegionsRepository {
  const RegionsRepository._();

  static Future<List<Map<String, dynamic>>> list() async {
    try {
      final rows = await sb.from('regions').select().order('name');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

/// testimonials — Approved Zitate für Landing/Marketing.
class TestimonialsRepository {
  const TestimonialsRepository._();

  static Future<List<Map<String, dynamic>>> featured() async {
    try {
      final rows = await sb
          .from('testimonials')
          .select(
              'id, quote, created_at, profiles!testimonials_user_id_fkey(name, display_name, avatar_url)')
          .eq('approved', true)
          .eq('featured', true)
          .order('created_at', ascending: false)
          .limit(10);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

/// contact_messages — Kontakt-Formular-Nachrichten.
class ContactMessagesRepository {
  const ContactMessagesRepository._();

  static Future<bool> send({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      await sb.from('contact_messages').insert({
        'name': name.trim(),
        'email': email.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
        'read': false,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// bot_feedback — Daumen hoch/runter auf Bot-Antworten.
class BotFeedbackRepository {
  const BotFeedbackRepository._();

  static Future<bool> rate({
    required String messageId,
    required String rating, // 'up' | 'down'
    String? question,
    String? answer,
    String? route,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    try {
      await sb.from('bot_feedback').insert({
        if (uid != null) 'user_id': uid,
        'message_id': messageId,
        'rating': rating,
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (route != null) 'route': route,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// feature_flags — Server-side Feature-Toggles (read-only für Client).
class FeatureFlagsRepository {
  const FeatureFlagsRepository._();

  static Future<Map<String, bool>> all() async {
    try {
      final rows = await sb
          .from('feature_flags')
          .select('name, enabled');
      final m = <String, bool>{};
      for (final r
          in (rows as List).whereType<Map<String, dynamic>>()) {
        m[r['name'] as String] = r['enabled'] as bool? ?? false;
      }
      return m;
    } catch (_) {
      return const {};
    }
  }
}

/// app_settings — Globale Settings (read-only für Client).
class AppSettingsRepository {
  const AppSettingsRepository._();

  static Future<Map<String, dynamic>> all() async {
    try {
      final rows = await sb.from('app_settings').select('key, value');
      final m = <String, dynamic>{};
      for (final r
          in (rows as List).whereType<Map<String, dynamic>>()) {
        m[r['key'] as String] = r['value'];
      }
      return m;
    } catch (_) {
      return const {};
    }
  }
}

/// widget_configs — Per-User Dashboard-Widget-Konfiguration.
class WidgetConfigsRepository {
  const WidgetConfigsRepository._();

  static Future<Map<String, dynamic>?> mine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('widget_configs')
          .select('config, updated_at')
          .eq('user_id', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> save(Map<String, dynamic> config) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('widget_configs').upsert({
        'user_id': uid,
        'config': config,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Logging ─────────────────────────────────────────────────────────

/// error_logs — Sende Flutter-Errors zentral nach Supabase.
class ErrorLogsRepository {
  const ErrorLogsRepository._();

  static Future<void> log({
    required String errorType,
    required String message,
    String? stack,
    String? appVersion,
    String? deviceInfo,
  }) async {
    // ROBUST: direkter REST-POST an crash_logs (RLS: anon INSERT erlaubt,
    // CHECK(true)). Funktioniert SOFORT — auch VOR Supabase.initialize() und
    // im Logout-State, weil weder Client noch Session nötig sind. So landen
    // auch Startup-Crashes in einer Tabelle, die serverseitig auslesbar ist.
    String? uid;
    try {
      uid = SupabaseService.currentUser?.id;
    } catch (_) {/* Client evtl. noch nicht initialisiert */}
    try {
      await http
          .post(
            Uri.parse('${Env.supabaseUrl}/rest/v1/crash_logs'),
            headers: {
              'apikey': Env.supabaseAnonKey,
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: jsonEncode({
              'user_id': uid,
              'platform': 'android',
              'error_type': errorType,
              'error_message':
                  message.substring(0, message.length.clamp(0, 4000)),
              'stack_trace': stack == null
                  ? null
                  : stack.substring(0, stack.length.clamp(0, 8000)),
              'context': deviceInfo,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {/* don't recurse */}
  }
}

/// audit_logs — Admin-Trace (Client kann eigene wichtige Actions loggen).
class AuditLogsRepository {
  const AuditLogsRepository._();

  static Future<void> log({
    required String action,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('audit_logs').insert({
        'actor_id': uid,
        'action': action,
        if (targetType != null) 'target_type': targetType,
        if (targetId != null) 'target_id': targetId,
        if (details != null) 'details': details,
      });
    } catch (_) {}
  }
}
