import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/interaction.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Interactions-Repository: aktive Interaktionen + Counts.
class InteractionsRepository {
  const InteractionsRepository._();

  /// Aktive Interaktionen des aktuellen Users (als Helper ODER Helped).
  /// Status pending / accepted / on_way / arrived (NICHT completed/cancelled).
  static Future<List<Interaction>> getActive() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('interactions')
          .select()
          .or('helper_id.eq.$uid,helped_id.eq.$uid')
          .inFilter('status', ['pending', 'accepted', 'on_way', 'arrived'])
          .order('updated_at', ascending: false);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Interaction.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Snapshot-Count aktive Interaktionen.
  static Future<int> activeCount() async {
    final list = await getActive();
    return list.length;
  }
}

/// Provider mit AsyncValue<int> fuer Dashboard-Stat.
final activeInteractionsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider);
  return InteractionsRepository.activeCount();
});
