/// SKILL: mensaena-features (UX-Welle1 H2)
/// Aggregierter Badge-Counter für Profile-Tab im Bottom-Nav.
/// Summiert Aktionen die der User noch beantworten/erledigen sollte:
///   - Eingehende Hilfe-Anfragen (interactions.status='pending', helped_id=me)
///   - Match-Vorschläge (matches.status='pending')
///   - Eingehende Freundschaftsanfragen (friendships.status='pending')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

final pendingActionsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return 0;
  int total = 0;
  // 1) Eingehende Hilfe-Anfragen
  try {
    final res = await sb
        .from('interactions')
        .select('id')
        .eq('helped_id', uid)
        .eq('status', 'pending')
        .limit(50);
    total += (res as List).length;
  } catch (_) {}
  // 2) Match-Vorschläge
  try {
    final res = await sb
        .from('matches')
        .select('id')
        .eq('matched_user_id', uid)
        .eq('status', 'pending')
        .limit(50);
    total += (res as List).length;
  } catch (_) {}
  // 3) Eingehende Freundschaftsanfragen
  try {
    final res = await sb
        .from('friendships')
        .select('id')
        .eq('addressee_id', uid)
        .eq('status', 'pending')
        .limit(50);
    total += (res as List).length;
  } catch (_) {}
  return total;
});
