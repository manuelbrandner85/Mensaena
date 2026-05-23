import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// User-Blocking — user_blocks(blocker_id, blocked_id, created_at).
/// 1:1 zu Web `/api/users/block`.
class UserBlocksRepository {
  const UserBlocksRepository._();

  /// Blockiert einen anderen Nutzer.
  static Future<bool> block(String blockedUserId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == blockedUserId) return false;
    try {
      await sb.from('user_blocks').insert({
        'blocker_id': uid,
        'blocked_id': blockedUserId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hebt eine Blockierung auf.
  static Future<bool> unblock(String blockedUserId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('user_blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedUserId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Liste der von mir blockierten User-IDs.
  static Future<Set<String>> myBlockedIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await sb
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['blocked_id'] as String)
          .toSet();
    } catch (_) {
      return const {};
    }
  }
}
