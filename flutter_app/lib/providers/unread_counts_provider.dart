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

final unreadDmCountProvider = StreamProvider<int>((ref) async* {
  final myId = SupabaseService.currentUser?.id;
  if (myId == null) {
    yield 0;
    return;
  }
  Future<int> fetch() async {
    try {
      final rows = await sb
          .from('messages')
          .select('id')
          .eq('receiver_id', myId)
          .isFilter('read_at', null)
          .limit(100);
      return (rows as List).length;
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
