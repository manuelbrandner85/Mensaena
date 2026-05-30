import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/farm_listing.dart';
import '../models/organization.dart';
import '../models/organization_review.dart';
import '../models/organization_stats.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Organizations + Farms: User-Land + Umkreis-Filter.
/// Posts/Beiträge bleiben global — diese Verzeichnisse sind lokal pro Land.
class OrganizationsRepository {
  const OrganizationsRepository._();

  /// Listet aktive Orgs für ein Land + optional gefiltert nach Umkreis.
  /// [country] = ISO-2 (DE/AT/CH/...). [center] + [radiusKm] = optional
  /// Client-Side Haversine-Filter. Wenn beides null → nur Land-Filter.
  static Future<List<Organization>> listForUser({
    required String country,
    int limit = 200,
    ({double lat, double lng})? center,
    int? radiusKm,
  }) async {
    try {
      final rows = await sb
          .from('organizations')
          .select()
          .eq('is_active', true)
          .eq('country', country)
          .order('is_verified', ascending: false)
          .order('name')
          .limit(limit);
      final all = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Organization.fromJson)
          .toList();
      if (center == null || radiusKm == null || radiusKm <= 0) return all;
      return all.where((o) {
        if (o.latitude == null || o.longitude == null) return true;
        final d = LocationService.haversineKm(
            center.lat, center.lng, o.latitude!, o.longitude!);
        return d <= radiusKm;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Behalten für Backward-Kompatibilität (z.B. Admin-Tools).
  static Future<List<Organization>> listActive({int limit = 100}) async {
    try {
      final rows = await sb
          .from('organizations')
          .select()
          .eq('is_active', true)
          .order('is_verified', ascending: false)
          .order('name')
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Organization.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Organization?> getById(String id) async {
    try {
      final row =
          await sb.from('organizations').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Organization.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Vorschlag aus User-Hand. Schreibt in organization_suggestions (admin
  /// review). Falls die Tabelle nicht existiert, Fallback auf direktes
  /// organizations-Insert mit is_active=false (Pending-State).
  static Future<bool> suggest({
    required String name,
    required String category,
    required String city,
    String country = 'DE',
    String? description,
    String? address,
    String? phone,
    String? email,
    String? website,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('organization_suggestions').insert({
        'user_id': uid,
        'name': name,
        'category': category,
        'description': description,
        'address': address,
        'city': city,
        'country': country,
        'phone': phone,
        'email': email,
        'website': website,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // Phase O1 — neue Methoden fuer Suche, Reviews, Stats
  // ═════════════════════════════════════════════════════════════════

  /// Sucht Organisationen ueber den Server-RPC `search_organizations_v2`.
  /// Fallback bei RPC-Fehler: direkter Query + clientseitiger Haversine.
  static Future<List<Organization>> search({
    String? searchText,
    String? category,
    bool verifiedOnly = false,
    double? lat,
    double? lng,
    double radiusKm = 50,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rpc = await sb.rpc<dynamic>('search_organizations_v2', params: {
        'p_search': searchText,
        'p_category': category,
        'p_verified_only': verifiedOnly,
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (rpc is List) {
        return rpc
            .whereType<Map<String, dynamic>>()
            .map(Organization.fromJson)
            .toList();
      }
      return const [];
    } catch (_) {
      // Fallback: einfacher Query + clientseitiger Filter
      try {
        var query = sb.from('organizations').select().eq('is_active', true);
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        if (verifiedOnly) {
          query = query.eq('is_verified', true);
        }
        if (searchText != null && searchText.trim().isNotEmpty) {
          final s = searchText.trim();
          query = query.or(
              'name.ilike.%$s%,description.ilike.%$s%,city.ilike.%$s%');
        }
        final rows = await query
            .order('is_verified', ascending: false)
            .order('name')
            .limit(limit);
        final all = (rows as List)
            .whereType<Map<String, dynamic>>()
            .map(Organization.fromJson)
            .toList();
        if (lat == null || lng == null || radiusKm <= 0) return all;
        return all.where((o) {
          if (o.latitude == null || o.longitude == null) return true;
          final d = LocationService.haversineKm(
              lat, lng, o.latitude!, o.longitude!);
          return d <= radiusKm;
        }).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Holt die aggregierten Verzeichnis-Stats via RPC `get_organization_stats`.
  static Future<OrganizationStats> fetchStats() async {
    try {
      final res = await sb.rpc<dynamic>('get_organization_stats');
      if (res is Map) {
        return OrganizationStats.fromJson(Map<String, dynamic>.from(res));
      }
      return OrganizationStats.empty();
    } catch (_) {
      return OrganizationStats.empty();
    }
  }

  /// Listet Bewertungen einer Organisation mit Profile-Join.
  static Future<List<OrganizationReview>> fetchReviews(
    String orgId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await sb
          .from('organization_reviews')
          .select('*, profiles:user_id(name, avatar_url, display_name)')
          .eq('organization_id', orgId)
          .eq('is_flagged', false)
          .order('helpful_count', ascending: false)
          .range(offset, offset + limit - 1);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(OrganizationReview.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Legt eine neue Bewertung an. Liefert true bei Erfolg.
  static Future<bool> createReview({
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

  /// Loescht eine eigene Bewertung (RLS schuetzt vor fremden Reviews).
  static Future<bool> deleteReview(String reviewId) async {
    try {
      await sb.from('organization_reviews').delete().eq('id', reviewId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle "hilfreich". Rueckgabe = neuer Zustand (true=hilfreich gesetzt).
  /// Pflegt zusaetzlich den Counter ueber RPCs increment/decrement.
  static Future<bool> toggleHelpful(String reviewId) async {
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
        try {
          await sb.rpc<dynamic>('decrement_helpful',
              params: {'p_review_id': reviewId});
        } catch (_) {}
        return false;
      }
      await sb.from('organization_review_helpful').insert({
        'review_id': reviewId,
        'user_id': uid,
      });
      try {
        await sb.rpc<dynamic>('increment_helpful',
            params: {'p_review_id': reviewId});
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Markiert eine Review als gemeldet (`is_flagged = true`).
  static Future<bool> reportReview(String reviewId, String reason) async {
    try {
      await sb.from('organization_reviews').update({
        'is_flagged': true,
        'report_reason': reason,
      }).eq('id', reviewId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class FarmsRepository {
  const FarmsRepository._();

  /// Listet aktive Höfe für ein Land + optional Umkreis-Filter (Haversine).
  static Future<List<FarmListing>> listForUser({
    required String country,
    int limit = 200,
    ({double lat, double lng})? center,
    int? radiusKm,
  }) async {
    try {
      final rows = await sb
          .from('farm_listings')
          .select()
          .eq('is_public', true)
          .eq('country', country)
          .order('is_verified', ascending: false)
          .order('name')
          .limit(limit);
      final all = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(FarmListing.fromJson)
          .toList();
      if (center == null || radiusKm == null || radiusKm <= 0) return all;
      return all.where((f) {
        if (f.latitude == null || f.longitude == null) return true;
        final d = LocationService.haversineKm(
            center.lat, center.lng, f.latitude!, f.longitude!);
        return d <= radiusKm;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<FarmListing>> listActive({int limit = 100}) async {
    try {
      final rows = await sb
          .from('farm_listings')
          .select()
          .eq('is_public', true)
          .order('is_verified', ascending: false)
          .order('name')
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(FarmListing.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<FarmListing?> getById(String id) async {
    try {
      final row =
          await sb.from('farm_listings').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return FarmListing.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Erstellt einen neuen Farm/Bauernhof-Eintrag (Nutzer-Eintrag).
  /// 1:1 zu Web /dashboard/supply/farm/add. Gibt slug zurück oder null.
  static Future<String?> create({
    required String name,
    required String city,
    required String category,
    String country = 'AT',
    String? description,
    String? address,
    String? postalCode,
    String? state,
    String? phone,
    String? email,
    String? website,
    List<String> products = const [],
    List<String> services = const [],
    List<String> deliveryOptions = const [],
    List<String> mediaUrls = const [],
    bool isBio = false,
    bool isSeasonal = false,
    String? region,
    double? latitude,
    double? longitude,
  }) async {
    final trimmedName = name.trim();
    final trimmedCity = city.trim();
    if (trimmedName.isEmpty || trimmedCity.isEmpty) return null;
    final slug = _slugify(trimmedName);
    try {
      await sb.from('farm_listings').insert({
        'name': trimmedName,
        'slug': slug,
        'category': category,
        if (region != null && region.trim().isNotEmpty)
          'region': region.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (postalCode != null && postalCode.trim().isNotEmpty)
          'postal_code': postalCode.trim(),
        'city': trimmedCity,
        if (state != null && state.trim().isNotEmpty)
          'state': state.trim(),
        'country': country,
        if (phone != null && phone.trim().isNotEmpty)
          'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim(),
        if (website != null && website.trim().isNotEmpty)
          'website': website.trim(),
        if (products.isNotEmpty) 'products': products,
        if (services.isNotEmpty) 'services': services,
        if (deliveryOptions.isNotEmpty)
          'delivery_options': deliveryOptions,
        'is_bio': isBio,
        'is_seasonal': isSeasonal,
        'is_verified': false,
        'is_public': true,
        'source_name': 'Nutzer-Eintrag',
        if (mediaUrls.isNotEmpty) ...{
          'image_url': mediaUrls.first,
          'media_urls': mediaUrls,
        },
      });
      return slug;
    } catch (_) {
      return null;
    }
  }

  static String _slugify(String input) {
    final umlauts = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};
    var s = input.toLowerCase();
    umlauts.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-|-$'), '');
    final suffix = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(36);
    return '$s-$suffix';
  }

  static Future<FarmListing?> getBySlug(String slug) async {
    try {
      final row = await sb
          .from('farm_listings')
          .select()
          .eq('slug', slug)
          .maybeSingle();
      if (row == null) return null;
      return FarmListing.fromJson(row);
    } catch (_) {
      return null;
    }
  }
}

final organizationsListProvider =
    FutureProvider<List<Organization>>((ref) async => OrganizationsRepository.listActive());
final organizationDetailProvider = FutureProvider.family<Organization?, String>(
    (ref, id) => OrganizationsRepository.getById(id));

/// Family-Provider mit Country + optional Center/Radius.
/// Key-Format: `country` oder `country|lat,lng|radius` für eindeutigen Cache.
final organizationsForUserProvider = FutureProvider.family<List<Organization>,
    ({String country, double? lat, double? lng, int? radiusKm})>((ref, args) {
  return OrganizationsRepository.listForUser(
    country: args.country,
    center: (args.lat != null && args.lng != null)
        ? (lat: args.lat!, lng: args.lng!)
        : null,
    radiusKm: args.radiusKm,
  );
});

final farmsListProvider =
    FutureProvider<List<FarmListing>>((ref) async => FarmsRepository.listActive());
final farmDetailProvider =
    FutureProvider.family<FarmListing?, String>((ref, id) => FarmsRepository.getById(id));

final farmsForUserProvider = FutureProvider.family<List<FarmListing>,
    ({String country, double? lat, double? lng, int? radiusKm})>((ref, args) {
  return FarmsRepository.listForUser(
    country: args.country,
    center: (args.lat != null && args.lng != null)
        ? (lat: args.lat!, lng: args.lng!)
        : null,
    radiusKm: args.radiusKm,
  );
});

// ── Phase O1: Suche, Stats, Reviews ─────────────────────────────────

/// Such-Provider. Key-Format: Record mit Filter-Argumenten fuer
/// deterministisches Caching.
final orgSearchProvider = FutureProvider.family<
    List<Organization>,
    ({
      String? searchText,
      String? category,
      bool verifiedOnly,
      double? lat,
      double? lng,
      double radiusKm,
      int limit,
      int offset,
    })>((ref, args) {
  return OrganizationsRepository.search(
    searchText: args.searchText,
    category: args.category,
    verifiedOnly: args.verifiedOnly,
    lat: args.lat,
    lng: args.lng,
    radiusKm: args.radiusKm,
    limit: args.limit,
    offset: args.offset,
  );
});

final orgStatsProvider = FutureProvider<OrganizationStats>(
    (ref) => OrganizationsRepository.fetchStats());

final orgReviewsProvider =
    FutureProvider.family<List<OrganizationReview>, String>(
        (ref, orgId) => OrganizationsRepository.fetchReviews(orgId));
