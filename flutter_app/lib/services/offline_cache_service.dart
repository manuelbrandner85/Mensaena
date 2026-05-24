/// SKILL: mensaena-features
/// OfflineCacheService (V21) — local cache + outbound queue for offline use.
///
/// Caches three "hot" data sets so the app boots into a non-empty UI even
/// without network:
///   - Posts list                    (key: cache_posts_v1)
///   - Conversations list            (key: cache_conversations_v1)
///   - Own profile                   (key: cache_my_profile_v1)
///
/// When the device is offline, mutating actions (create post, send chat
/// message, …) are appended to an outbound queue and flushed automatically
/// once connectivity returns. Each queue entry carries a `type` discriminator
/// so callers know how to re-post the payload.
///
/// All persistence goes through `flutter_secure_storage` (no
/// shared_preferences in pubspec). Values are JSON-encoded strings.
///
/// Connectivity is exposed through [isOnlineProvider], a Riverpod
/// StreamProvider that surfaces the current online/offline state to the UI
/// (offline banner, "queued" badges, …).
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage keys.
const String kCachePostsKey = 'cache_posts_v1';
const String kCacheConversationsKey = 'cache_conversations_v1';
const String kCacheMyProfileKey = 'cache_my_profile_v1';
const String kCacheOutboundQueueKey = 'cache_outbound_queue_v1';

/// Signature for a flush handler. Receives one queued entry and must return
/// `true` if it was successfully posted to the backend, `false` otherwise.
typedef OutboundFlushHandler =
    Future<bool> Function(String type, Map<String, dynamic> payload);

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Optional callback used by [flushOutbound] to actually replay queued
  /// actions against the backend. Wired up from the bootstrap layer.
  OutboundFlushHandler? flushHandler;

  // ── Posts cache ────────────────────────────────────────────────────

  Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    await _writeList(kCachePostsKey, posts);
  }

  Future<List<Map<String, dynamic>>> loadCachedPosts() async {
    return _readList(kCachePostsKey);
  }

  // ── Conversations cache ────────────────────────────────────────────

  Future<void> cacheConversations(
    List<Map<String, dynamic>> conversations,
  ) async {
    await _writeList(kCacheConversationsKey, conversations);
  }

  Future<List<Map<String, dynamic>>> loadCachedConversations() async {
    return _readList(kCacheConversationsKey);
  }

  // ── Profile cache ──────────────────────────────────────────────────

  Future<void> cacheMyProfile(Map<String, dynamic> profile) async {
    try {
      await _storage.write(
        key: kCacheMyProfileKey,
        value: jsonEncode(profile),
      );
    } catch (e) {
      debugPrint('OfflineCacheService: profile write failed: $e');
    }
  }

  Future<Map<String, dynamic>?> loadCachedMyProfile() async {
    try {
      final raw = await _storage.read(key: kCacheMyProfileKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      debugPrint('OfflineCacheService: profile read failed: $e');
      return null;
    }
  }

  // ── Outbound queue ─────────────────────────────────────────────────

  /// Append an action that should be re-tried when connectivity returns.
  Future<void> cacheQueueOutbound(
    String type,
    Map<String, dynamic> payload,
  ) async {
    final queue = await _loadOutboundQueue();
    queue.add({
      'type': type,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _writeList(kCacheOutboundQueueKey, queue);
  }

  /// Replays every queued action via [flushHandler]. Successful entries are
  /// removed; failed entries stay in the queue for the next attempt.
  /// Returns the number of entries that were successfully flushed.
  Future<int> flushOutbound() async {
    final handler = flushHandler;
    if (handler == null) return 0;

    final queue = await _loadOutboundQueue();
    if (queue.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var flushed = 0;
    for (final entry in queue) {
      final type = entry['type'] as String? ?? '';
      final payloadRaw = entry['payload'];
      final payload = payloadRaw is Map<String, dynamic>
          ? payloadRaw
          : Map<String, dynamic>.from((payloadRaw as Map?) ?? const {});
      var ok = false;
      try {
        ok = await handler(type, payload);
      } catch (e) {
        debugPrint('OfflineCacheService: flush handler threw: $e');
        ok = false;
      }
      if (ok) {
        flushed++;
      } else {
        remaining.add(entry);
      }
    }
    await _writeList(kCacheOutboundQueueKey, remaining);
    return flushed;
  }

  /// Read-only access to the current outbound queue (for debug / UI badges).
  Future<List<Map<String, dynamic>>> peekOutbound() => _loadOutboundQueue();

  Future<List<Map<String, dynamic>>> _loadOutboundQueue() =>
      _readList(kCacheOutboundQueueKey);

  // ── Generic helpers ────────────────────────────────────────────────

  Future<void> _writeList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    try {
      await _storage.write(key: key, value: jsonEncode(value));
    } catch (e) {
      debugPrint('OfflineCacheService: write "$key" failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('OfflineCacheService: read "$key" failed: $e');
      return const [];
    }
  }
}

/// Riverpod accessor for the singleton.
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService.instance;
});

/// Streams the device connectivity state as a boolean (true = online).
/// Wraps `connectivity_plus` and considers anything that's not "none" as
/// online. Surfaces the initial state immediately.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  final connectivity = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // Push initial value asap so subscribers don't sit on a loading state.
  connectivity.checkConnectivity().then((results) {
    if (!controller.isClosed) controller.add(isOnline(results));
  }).catchError((_) {
    if (!controller.isClosed) controller.add(true);
  });

  final sub = connectivity.onConnectivityChanged.listen((results) {
    if (!controller.isClosed) controller.add(isOnline(results));
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
