import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_comment.dart';
import '../models/board_post.dart';
import '../services/location_anonymizer.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Board (Schwarzes Brett) — Posts, Comments, Pins.
class BoardRepository {
  const BoardRepository._();

  static Future<List<BoardPost>> listActive({int limit = 50}) async {
    try {
      final rows = await sb
          .from('board_posts')
          .select()
          .eq('status', 'active')
          // Abgelaufene Posts ausblenden: Pinnwand-Einträge haben oft ein
          // expires_at (z.B. Veranstaltung in 2 Wochen). Vorher kein Filter →
          // alte Aushänge blieben sichtbar, bis sie manuell gelöscht wurden.
          // Posts OHNE expires_at bleiben sichtbar (kein Ablauf gewählt).
          .or('expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}')
          .order('pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BoardPost.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<BoardPost?> getById(String id) async {
    try {
      final row = await sb
          .from('board_posts')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return BoardPost.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> create({
    required String content,
    required String category,
    required String color,
    String? contactInfo,
    DateTime? expiresAt,
    String? imageUrl,
    List<String> mediaUrls = const [],
    double? latitude,
    double? longitude,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('board_posts')
          .insert({
            'author_id': uid,
            'content': content,
            'category': category,
            'color': color,
            'contact_info': contactInfo,
            'expires_at': expiresAt?.toUtc().toIso8601String(),
            if (imageUrl != null) 'image_url': imageUrl,
            if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
            if (latitude != null) 'latitude': LocationAnonymizer.lat(latitude),
            if (longitude != null) 'longitude': LocationAnonymizer.lng(longitude),
            'status': 'active',
            'pinned': false,
            'pin_count': 0,
            'comment_count': 0,
          })
          .select()
          .maybeSingle();
      // maybeSingle liefert null wenn RLS den Insert verhindert ODER
      // wenn das Select keinen Row zurueckliefert. Beides = fail.
      if (row == null) return null;
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> togglePin(String boardPostId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('board_pins')
          .select('id')
          .eq('board_post_id', boardPostId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('board_pins')
            .delete()
            .eq('board_post_id', boardPostId)
            .eq('user_id', uid);
      } else {
        await sb.from('board_pins').insert({
          'board_post_id': boardPostId,
          'user_id': uid,
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isPinned(String boardPostId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('board_pins')
          .select('id')
          .eq('board_post_id', boardPostId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BoardComment>> commentsFor(String boardPostId) async {
    try {
      final rows = await sb
          .from('board_comments')
          .select()
          .eq('board_post_id', boardPostId)
          .order('created_at');
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BoardComment.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> addComment({
    required String boardPostId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('board_comments').insert({
        'board_post_id': boardPostId,
        'author_id': uid,
        'content': content,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Inhalt eines eigenen Board-Posts aktualisieren.
  static Future<bool> update({
    required String id,
    String? content,
    String? category,
    String? color,
    String? contactInfo,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? imageUrl,
    bool clearImageUrl = false,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (content != null) 'content': content,
        if (category != null) 'category': category,
        if (color != null) 'color': color,
        if (contactInfo != null)
          'contact_info': contactInfo.isEmpty ? null : contactInfo,
        if (clearExpiresAt)
          'expires_at': null
        else if (expiresAt != null)
          'expires_at': expiresAt.toUtc().toIso8601String(),
        if (clearImageUrl)
          'image_url': null
        else if (imageUrl != null)
          'image_url': imageUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await sb.from('board_posts').update(patch).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigenen Board-Post loeschen (RLS prueft Eigentuemer).
  static Future<bool> delete(String id) async {
    try {
      await sb.from('board_posts').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<List<BoardPost>> watchActive() {
    return sb
        .from('board_posts')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows
            .whereType<Map<String, dynamic>>()
            .map(BoardPost.fromJson)
            .toList());
  }
}

final boardActiveStreamProvider =
    StreamProvider.autoDispose<List<BoardPost>>(
        (ref) => BoardRepository.watchActive());

final boardPostsProvider =
    FutureProvider<List<BoardPost>>((ref) async => BoardRepository.listActive());

final boardPostDetailProvider =
    FutureProvider.family<BoardPost?, String>((ref, id) => BoardRepository.getById(id));

final boardCommentsProvider =
    FutureProvider.family<List<BoardComment>, String>(
        (ref, id) => BoardRepository.commentsFor(id));

final boardIsPinnedProvider =
    FutureProvider.family<bool, String>((ref, id) => BoardRepository.isPinned(id));
