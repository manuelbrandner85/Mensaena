/// SKILL: mensaena-architektur (Phase 0 L44 + R28)
/// BlockGuard — zentrale Vor-Prüfung für alle User-zu-User-Interaktionen.
///
/// Verwendung:
///   if (!await BlockGuard.canInteract(targetUserId)) {
///     showSnackBar('block.cannotInteract'.tr());
///     return;
///   }
///
/// Cacht das Ergebnis 60 Sekunden pro Target um wiederholte DB-Calls bei
/// schnellen UI-Aktionen (z.B. Liste durchscrollen mit FollowButton) zu
/// vermeiden. Cache wird via invalidate() nach Block/Unblock-Aktionen
/// geleert.
library;

import 'dart:async';

import '../repositories/user_blocks_repository.dart';

class BlockGuard {
  const BlockGuard._();

  static final Map<String, _CacheEntry> _cache = {};
  static const _ttl = Duration(seconds: 60);

  /// `true` = Interaktion erlaubt, `false` = einer der beiden hat den
  /// anderen geblockt (welcher: egal — Interaktion blockiert in beide
  /// Richtungen).
  static Future<bool> canInteract(String targetUserId) async {
    final cached = _cache[targetUserId];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _ttl) {
      return !cached.blocked;
    }
    final blocked =
        await UserBlocksRepository.isBlockedEitherWay(targetUserId);
    _cache[targetUserId] = _CacheEntry(blocked: blocked, at: DateTime.now());
    return !blocked;
  }

  /// Direkter Negativ-Check (zum Anzeigen von "Geblockt"-Hinweis).
  static Future<bool> isBlocked(String targetUserId) async {
    return !(await canInteract(targetUserId));
  }

  /// Cache leeren — nach Block/Unblock unbedingt aufrufen.
  static void invalidate([String? targetUserId]) {
    if (targetUserId == null) {
      _cache.clear();
    } else {
      _cache.remove(targetUserId);
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.blocked, required this.at});
  final bool blocked;
  final DateTime at;
}
