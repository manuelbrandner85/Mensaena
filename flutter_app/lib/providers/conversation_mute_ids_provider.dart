/// SKILL: mensaena-features (P2) — Mute-Status für alle eigenen
/// Conversations in einem Query, gecached.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

final mutedConversationIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const {};
  try {
    final rows = await sb
        .from('conversation_members')
        .select('conversation_id, muted_until')
        .eq('user_id', uid)
        .eq('is_muted', true)
        .limit(1000);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .where((r) {
          final until = r['muted_until'] as String?;
          if (until == null) return true;
          return (DateTime.tryParse(until)?.isAfter(DateTime.now())) ?? true;
        })
        .map((r) => r['conversation_id'] as String)
        .toSet();
  } catch (_) {
    return const {};
  }
});
