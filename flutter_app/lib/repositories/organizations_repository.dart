import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/farm_listing.dart';
import '../models/organization.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
class OrganizationsRepository {
  const OrganizationsRepository._();

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

final farmsListProvider =
    FutureProvider<List<FarmListing>>((ref) async => FarmsRepository.listActive());
final farmDetailProvider =
    FutureProvider.family<FarmListing?, String>((ref, id) => FarmsRepository.getById(id));
