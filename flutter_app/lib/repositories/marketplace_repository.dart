import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../models/marketplace_listing.dart';
import '../services/location_anonymizer.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Marktplatz — Listings: list/getById/create. KEIN kommerzieller Handel,
/// Werte sind verschenken/tauschen/günstig abgeben.
class MarketplaceRepository {
  const MarketplaceRepository._();

  static Future<List<MarketplaceListing>> listActive({
    String? listingType,
    int limit = 100,
    bool includeClaimed = false,
  }) async {
    try {
      var query = sb.from('marketplace_listings').select();
      if (!includeClaimed) {
        // active + reserved (default Marketplace view)
        query = query.inFilter('status', const ['active', 'reserved']);
      }
      if (listingType != null && listingType != 'all') {
        query = query.eq('listing_type', listingType);
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(MarketplaceListing.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Tausch-Angebote derselben Kategorie (Barter-Matches), max 5.
  static Future<List<Map<String, dynamic>>> barterMatches({
    required String listingId,
    required String category,
  }) async {
    try {
      final rows = await sb
          .from('marketplace_listings')
          .select('id, title, category, images, image_urls, user_id')
          .neq('id', listingId)
          .eq('listing_type', 'tauschen')
          .eq('category', category)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Durchschnittspreis einer Kategorie (letzte 90 Tage, price>0) oder null.
  static Future<double?> averagePrice(String category) async {
    try {
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 90))
          .toIso8601String();
      final rows = await sb
          .from('marketplace_listings')
          .select('price')
          .eq('category', category)
          .gte('created_at', since)
          .gt('price', 0);
      final prices = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (r['price'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (prices.isEmpty) return null;
      return prices.reduce((a, b) => a + b) / prices.length;
    } catch (_) {
      return null;
    }
  }

  /// Lädt aktive giveaway- und swap-Listings für den Sharing-Screen.
  static Future<List<MarketplaceListing>> listSharing({int limit = 50}) async {
    try {
      final rows = await sb
          .from('marketplace_listings')
          .select()
          .inFilter('listing_type', const ['giveaway', 'swap'])
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(MarketplaceListing.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<MarketplaceListing?> getById(String id) async {
    try {
      final row = await sb
          .from('marketplace_listings')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return MarketplaceListing.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> create({
    required String title,
    required String description,
    required String category,
    required String listingType,
    String? conditionState,
    double? price,
    String priceType = 'fixed',
    String? locationText,
    double? latitude,
    double? longitude,
    List<String> tags = const [],
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('marketplace_listings')
          .insert({
            'user_id': uid,
            'seller_id': uid,
            'title': title,
            'description': description,
            'category': category,
            'listing_type': listingType,
            'condition_state': conditionState,
            'price': price,
            'price_type': priceType,
            'location_text': locationText,
            'latitude': latitude != null ? LocationAnonymizer.lat(latitude) : null,
            'longitude': longitude != null ? LocationAnonymizer.lng(longitude) : null,
            if (tags.isNotEmpty) 'tags': tags,
            'status': 'active',
          })
          .select()
          .maybeSingle();
      if (row == null) return null;
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Hängt die hochgeladenen Bild-URLs an ein bestehendes Listing
  /// (nach dem Bild-Upload im Create-Flow).
  static Future<void> updateImages(
      String listingId, List<String> imageUrls) async {
    try {
      await sb
          .from('marketplace_listings')
          .update({'images': imageUrls}).eq('id', listingId);
    } catch (_) {/* Bilder optional — Listing existiert bereits */}
  }

  /// Interessent fragt ein Listing an (Reservierungs-WUNSCH in
  /// marketplace_reservations — nicht der Status-Flip des Listings).
  static Future<bool> requestReservation({
    required String listingId,
    String? message,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('marketplace_reservations').insert({
        'listing_id': listingId,
        'user_id': uid,
        'message': (message != null && message.trim().isNotEmpty)
            ? message.trim()
            : null,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mark a listing as 'claimed' (given away). Owner only.
  static Future<bool> markAsClaimed(String listingId) async {
    try {
      await sb.from('marketplace_listings').update({
        'status': 'claimed',
      }).eq('id', listingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reserve a listing for a user. Status set to 'reserved'. Owner only.
  static Future<bool> reserveListing({
    required String listingId,
    required String userId,
  }) async {
    try {
      await sb.from('marketplace_listings').update({
        'reserved_for': userId,
        'status': 'reserved',
      }).eq('id', listingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lift a reservation. Status returns to 'active'.
  static Future<bool> unreserveListing(String listingId) async {
    try {
      await sb.from('marketplace_listings').update({
        'reserved_for': null,
        'status': 'active',
      }).eq('id', listingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Counts for the list header: active listings, of which free, claimed.
  /// 'free' = price_type == 'free' OR listing_type == 'giveaway' OR price == 0.
  static Future<Map<String, int>> countStats() async {
    try {
      final all = await sb
          .from('marketplace_listings')
          .select('status, price_type, listing_type, price');
      final list = (all as List).whereType<Map<String, dynamic>>().toList();
      final active = list
          .where((r) => r['status'] == 'active' || r['status'] == 'reserved')
          .length;
      final free = list.where((r) =>
          (r['status'] == 'active' || r['status'] == 'reserved') &&
          (r['price_type'] == 'free' ||
              r['listing_type'] == 'giveaway' ||
              (r['price'] as num?) == 0)).length;
      final claimed = list
          .where((r) => r['status'] == 'claimed' || r['status'] == 'sold')
          .length;
      return {'active': active, 'free': free, 'claimed': claimed};
    } catch (_) {
      return const {'active': 0, 'free': 0, 'claimed': 0};
    }
  }

  /// Upload image bytes to Supabase Storage. Vorher: silently auf
  /// 'chat-images' gefallen, jetzt: nur 'marketplace-images'.
  static Future<String?> uploadListingImage({
    required Uint8List bytes,
    required String userId,
    required String fileExt, // 'jpg'/'png'/'webp'
  }) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '$userId/$filename';
    try {
      await sb.storage.from('marketplace-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      return sb.storage.from('marketplace-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadListingImage failed: $e');
      return null;
    }
  }

  // ── M1: Inserat-Kommentare ──────────────────────────────────────────
  /// Lädt Kommentare zu einem Inserat (älteste zuerst) inkl. Autor-Profil.
  static Future<List<Map<String, dynamic>>> listComments(
      String listingId) async {
    try {
      final rows = await sb
          .from('marketplace_comments')
          .select(
              'id, listing_id, user_id, content, created_at, '
              'profiles(id, name, display_name, avatar_url)')
          .eq('listing_id', listingId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true)
          .limit(200);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> addComment(String listingId, String content) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final text = content.trim();
    if (text.isEmpty) return false;
    try {
      await sb.from('marketplace_comments').insert({
        'listing_id': listingId,
        'user_id': uid,
        'content': text,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Soft-Delete eines Inserats (deleted_at setzen). Owner only via RLS.
  static Future<bool> deleteListing(String id) async {
    try {
      await sb
          .from('marketplace_listings')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Soft-Delete (eigener Kommentar) bzw. Hard-Delete (Inserats-Besitzer
  /// via RLS). Wir versuchen Soft-Delete; RLS lässt es zu solange erlaubt.
  static Future<bool> deleteComment(String commentId) async {
    try {
      await sb
          .from('marketplace_comments')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', commentId);
      return true;
    } catch (_) {
      // Fallback: harter Delete (z.B. wenn Besitzer moderiert).
      try {
        await sb.from('marketplace_comments').delete().eq('id', commentId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}

/// Family-Provider für die Kommentar-Liste eines Inserats.
final marketplaceCommentsProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
  (ref, listingId) => MarketplaceRepository.listComments(listingId),
);

final marketplaceListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>(
        (ref, type) => MarketplaceRepository.listActive(listingType: type));

/// Family-Variante mit includeClaimed-Flag — key: (type, includeClaimed).
final marketplaceListingsFilteredProvider = FutureProvider.family<
    List<MarketplaceListing>, ({String type, bool includeClaimed})>(
  (ref, key) => MarketplaceRepository.listActive(
    listingType: key.type,
    includeClaimed: key.includeClaimed,
  ),
);

final marketplaceDetailProvider =
    FutureProvider.family<MarketplaceListing?, String>(
        (ref, id) => MarketplaceRepository.getById(id));

final marketplaceStatsProvider = FutureProvider<Map<String, int>>(
  (ref) => MarketplaceRepository.countStats(),
);

/// Favoriten-Helpers — `marketplace_favorites` Tabelle (1:1 zu Web).
class MarketplaceFavorites {
  const MarketplaceFavorites._();

  /// Toggle: Listing speichern oder Save entfernen.
  static Future<bool> toggle(String listingId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('marketplace_favorites')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('marketplace_favorites')
            .delete()
            .eq('id', existing['id'] as Object);
        return false;
      }
      await sb.from('marketplace_favorites').insert({
        'listing_id': listingId,
        'user_id': uid,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// IDs aller gespeicherten Listings des aktuellen Users.
  static Future<Set<String>> getSavedIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await sb
          .from('marketplace_favorites')
          .select('listing_id')
          .eq('user_id', uid);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['listing_id'] as String)
          .toSet();
    } catch (_) {
      return const {};
    }
  }
}

final savedListingIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  return MarketplaceFavorites.getSavedIds();
});

final sharingListingsProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>(
  (ref) => MarketplaceRepository.listSharing(),
);
