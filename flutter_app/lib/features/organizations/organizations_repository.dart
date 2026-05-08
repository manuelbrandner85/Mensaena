import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final organizationsRepositoryProvider = Provider<OrganizationsRepository>(
  (ref) => OrganizationsRepository(ref.read(supabaseProvider)),
);

class OrganizationsRepository {
  OrganizationsRepository(this._db);
  final SupabaseClient _db;
  static const _pageSize = 20;

  Future<List<Organization>> list({
    String search = '',
    String category = 'all',
    bool verifiedOnly = false,
    int page = 0,
  }) async {
    var query = _db.from('organizations').select('*').eq('is_active', true);
    if (category != 'all') {
      query = query.eq('category', category);
    }
    if (verifiedOnly) {
      query = query.eq('is_verified', true);
    }
    if (search.trim().isNotEmpty) {
      final term = _escapeIlike(_sanitizeForOr(search));
      if (term.isNotEmpty) {
        query = query.or(
          'name.ilike.%$term%,address.ilike.%$term%,description.ilike.%$term%,city.ilike.%$term%',
        );
      }
    }

    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    final rows = await query.order('name').range(from, to);
    return rows.map(Organization.fromJson).toList();
  }

  Future<Organization?> fetch(String idOrSlug) async {
    Map<String, dynamic>? row;
    // Try as slug first (most URLs use slug)
    row = await _db
        .from('organizations')
        .select('*')
        .eq('slug', idOrSlug)
        .maybeSingle();
    row ??= await _db
        .from('organizations')
        .select('*')
        .eq('id', idOrSlug)
        .maybeSingle();
    if (row == null) return null;
    return Organization.fromJson(row);
  }

  Future<void> suggest({
    required String name,
    required String city,
    required String category,
    String? address,
    String? zipCode,
    String? country,
    String? phone,
    String? email,
    String? website,
    String? description,
    String? sourceUrl,
  }) async {
    final user = _db.auth.currentUser;
    final payload = <String, dynamic>{
      'name': name,
      'city': city,
      'category': category,
      'country': country ?? 'Österreich',
      if (address != null && address.isNotEmpty) 'address': address,
      if (zipCode != null && zipCode.isNotEmpty) 'zip_code': zipCode,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (website != null && website.isNotEmpty) 'website': website,
      if (description != null && description.isNotEmpty) 'description': description,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      if (user != null) 'suggested_by': user.id,
      'status': 'pending',
    };
    await _db.from('organization_suggestions').insert(payload);
  }

  static String _sanitizeForOr(String value) =>
      value.replaceAll(RegExp(r'[,()"\\]'), ' ').trim();

  static String _escapeIlike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
}
