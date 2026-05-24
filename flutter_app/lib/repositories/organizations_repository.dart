import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/farm_listing.dart';
import '../models/organization.dart';
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
