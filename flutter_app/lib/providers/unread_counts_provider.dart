/// SKILL: mensaena-features
/// UnreadCountsProvider — Realtime-Badges fuer BottomNav.
///
/// Web hat 3 separate Badges (Messages, Crises, Interactions). Hier
/// vorerst nur Messages (DM-Unread) — Crises + Interactions koennen
/// nachgezogen werden sobald Push-Streams existieren.
///
/// Polling alle 30s statt Stream weil:
///   - sb.from('messages').stream() liefert ALLE messages-Inserts der
///     Conversations in denen ich Mitglied bin → potenziell hunderte
///     pro Minute = Akku + Realtime-Connection-Spam.
///   - Polling ist konstanter Load + planbar.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// F8: Unread-Counts pro Konversation (für Badge im messages_screen).
/// 30s-Polling — matched die Logik vom globalen unreadDmCountProvider.
final perConversationUnreadProvider =
    StreamProvider<Map<String, int>>((ref) async* {
  final myId = SupabaseService.currentUser?.id;
  if (myId == null) {
    yield const <String, int>{};
    return;
  }
  Future<Map<String, int>> fetch() async {
    try {
      final rows = await sb
          .from('v_unread_counts')
          .select('conversation_id, unread_count')
          .eq('user_id', myId);
      final map = <String, int>{};
      for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
        final cid = r['conversation_id'] as String?;
        final cnt = (r['unread_count'] as num?)?.toInt() ?? 0;
        if (cid != null && cnt > 0) map[cid] = cnt;
      }
      return map;
    } catch (_) {
      return const <String, int>{};
    }
  }

  yield await fetch();
  await for (final _
      in Stream<void>.periodic(const Duration(seconds: 30))) {
    yield await fetch();
  }
});

final unreadDmCountProvider = StreamProvider<int>((ref) async* {
  final myId = SupabaseService.currentUser?.id;
  if (myId == null) {
    yield 0;
    return;
  }
  Future<int> fetch() async {
    try {
      // BUGFIX: messages.receiver_id / read_at sind im DM-Modell IMMER null
      // (Lesestatus läuft über conversation_members.last_read_at). Die alte
      // Query lieferte daher KONSTANT 0 → das BottomNav-DM-Badge erschien
      // nie. Jetzt aus v_unread_counts summieren — dieselbe Quelle, die der
      // perConversationUnreadProvider bereits korrekt nutzt.
      final rows = await sb
          .from('v_unread_counts')
          .select('unread_count')
          .eq('user_id', myId);
      var total = 0;
      for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
        total += (r['unread_count'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  yield await fetch();
  await for (final _
      in Stream<void>.periodic(const Duration(seconds: 30))) {
    yield await fetch();
  }
});
