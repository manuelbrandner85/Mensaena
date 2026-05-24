import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace_listing.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Marktplatz — Listings: list/getById/create. KEIN kommerzieller Handel,
/// Werte sind verschenken/tauschen/günstig abgeben.
class MarketplaceRepository {
  const MarketplaceRepository._();

  static Future<List<MarketplaceListing>> listActive({
    String? listingType,
    int limit = 100,
  }) async {
    try {
      var query = sb.from('marketplace_listings').select().eq('status', 'active');
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
            'latitude': latitude,
            'longitude': longitude,
            'status': 'active',
          })
          .select()
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final marketplaceListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>(
        (ref, type) => MarketplaceRepository.listActive(listingType: type));

final marketplaceDetailProvider =
    FutureProvider.family<MarketplaceListing?, String>(
        (ref, id) => MarketplaceRepository.getById(id));

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
