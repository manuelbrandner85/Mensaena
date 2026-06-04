import '../services/block_guard.dart';
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
      BlockGuard.invalidate(blockedUserId);
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
      BlockGuard.invalidate(blockedUserId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True wenn ich den User blockiert habe ODER er mich blockiert hat.
  /// R17: Beidseitiger Check vor Kontakt/DM/Call.
  static Future<bool> isBlockedEitherWay(String otherUserId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await sb
          .from('user_blocks')
          .select('id')
          .or('and(blocker_id.eq.$uid,blocked_id.eq.$otherUserId),and(blocker_id.eq.$otherUserId,blocked_id.eq.$uid)')
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// IDs aller User die ICH blockiert habe ODER die MICH blockiert haben.
  /// FIX H2: bidirektional über die SECURITY-DEFINER-RPC my_block_filter_ids —
  /// so verschwinden auch Beiträge/Aktivitäten von Usern, die mich blockiert
  /// haben, aus meinem Feed (Stalking-/Harassment-Schutz). Die RPC verrät
  /// NICHT, wer in welche Richtung blockiert hat.
  static Future<Set<String>> myBlockedIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await sb.rpc<dynamic>('my_block_filter_ids');
      if (rows is List) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map((r) => r['user_id'] as String?)
            .whereType<String>()
            .toSet();
      }
      return const {};
    } catch (_) {
      // Fallback auf einseitig (besser als gar kein Filter), falls die RPC
      // noch nicht deployed ist.
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
}
