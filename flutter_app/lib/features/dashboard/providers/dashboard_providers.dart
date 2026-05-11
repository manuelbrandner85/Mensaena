// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import, strict_raw_types, avoid_dynamic_calls
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase/database_service.dart';
import '../../../services/supabase/supabase_service.dart';

class DashboardStats {
  final int activeNeighbors;
  final int helpOffers;
  final int interactions;
  final int regions;

  const DashboardStats({
    this.activeNeighbors = 0,
    this.helpOffers = 0,
    this.interactions = 0,
    this.regions = 0,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final since = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
  // Parallele Count-Queries via select+length — funktioniert universell ohne
  // Abhaengigkeit von der jeweiligen Postgrest .count()-API-Variante.
  final results = await Future.wait<int>([
    _selectCount('profiles', filter: (q) => q.gte('last_active', since)),
    _selectCount('posts', filter: (q) => q.eq('type', 'hilfeAnbieten')),
    _selectCount('interactions'),
    _selectCount('regions'),
  ]);
  return DashboardStats(
    activeNeighbors: results[0],
    helpOffers: results[1],
    interactions: results[2],
    regions: results[3],
  );
});

Future<int> _selectCount(
  String table, {
  dynamic Function(dynamic q)? filter,
}) async {
  try {
    dynamic query = supabase.client.from(table).select('id');
    if (filter != null) query = filter(query);
    final list = await query;
    if (list is List) return list.length;
    return 0;
  } catch (_) {
    return 0;
  }
}

final dashboardFeedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return db.listFeedPosts(limit: 20);
});
