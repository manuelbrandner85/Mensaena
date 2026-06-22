import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Conversations + Messages. Realtime-Subscribe pro Conversation.
class ConversationsRepository {
  const ConversationsRepository._();

  /// Alle Community-Channels (chat_channels) gruppiert nach category.
  /// 1:1 zu Web `loadChannels`. Returns Map mit channels-Liste + sort.
  static Future<List<Map<String, dynamic>>> listChannels() async {
    try {
      final rows = await sb
          .from('chat_channels')
          .select(
              'id, conversation_id, name, emoji, slug, description, category, is_locked, sort_order, avatar_url, created_by')
          .order('sort_order')
          .limit(200);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Erstellt einen Community-Kanal. NUR donor_tier>=2 ("Förderer") — wird
  /// serverseitig per RLS (channels_donor_insert) erzwungen; die UI zeigt den
  /// Button ohnehin nur berechtigten Nutzer:innen. Legt eine conversation
  /// (type 'group') + die chat_channels-Row an (1:1 zur Web-CreateChannelModal).
  /// Gibt die neue Channel-Row zurück oder null bei Fehler.
  /// Erstellt einen Community-Raum atomar serverseitig (RPC, SECURITY DEFINER):
  /// legt Conversation + Owner-Mitgliedschaft + Kanal an. Behebt den früheren
  /// Fehler, dass der Readback nach dem Insert an der conv_select-RLS scheiterte
  /// (Ersteller war noch kein Mitglied). Unterstützt Kategorie + öffentlich/privat.
  static Future<Map<String, dynamic>?> createChannel({
    required String name,
    String emoji = '💬',
    String? description,
    String category = 'Community',
    bool isPrivate = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final res = await sb.rpc<dynamic>(
        'create_community_channel',
        params: {
          'p_name': trimmed,
          'p_emoji': emoji,
          'p_description': description?.trim(),
          'p_category': category,
          'p_is_private': isPrivate,
        },
      );
      if (res is Map) return res.cast<String, dynamic>();
      if (res is List && res.isNotEmpty && res.first is Map) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Löscht einen selbst erstellten Community-Raum (Kanal). Nur der Ersteller
  /// (chat_channels.created_by / Member-Rolle 'owner') oder ein Admin darf das
  /// — die Berechtigung wird serverseitig in der SECURITY-DEFINER-RPC geprüft.
  /// CASCADE entfernt Kanal, Mitglieder und alle Nachrichten.
  static Future<bool> deleteChannel(String conversationId) async {
    try {
      await sb.rpc<dynamic>(
        'delete_community_channel',
        params: {'p_conversation': conversationId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigene Konversationen sortiert nach last_message_at (neueste oben).
  static Future<List<Map<String, dynamic>>> listMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final memberships = await sb
          .from('conversation_members')
          .select('conversation_id, last_read_at, hidden_at, '
              'conversations(id,type,title,updated_at,created_at)')
          .eq('user_id', uid)
          .filter('hidden_at', 'is', null);
      final rows = (memberships as List).whereType<Map<String, dynamic>>();
      final result = <Map<String, dynamic>>[];
      final convIds = <String>[];
      for (final r in rows) {
        final conv = r['conversations'] as Map<String, dynamic>?;
        if (conv == null) continue;
        convIds.add(conv['id'] as String);
        result.add({
          ...conv,
          'last_read_at': r['last_read_at'],
        });
      }

      // Enrich mit Channel-Info (chat_channels) + Partner-Profile in
      // einem Batch — 1:1 zu Web wo wir gleichzeitig channel.name +
      // partner.display_name fuer die Conversation-Liste auflösen.
      if (convIds.isNotEmpty) {
        // 1. Channels per conversation_id Lookup
        final channels = await sb
            .from('chat_channels')
            .select(
                'conversation_id, name, emoji, slug, description, is_locked')
            .inFilter('conversation_id', convIds);
        final channelByConv = <String, Map<String, dynamic>>{};
        for (final c in (channels as List)
            .whereType<Map<String, dynamic>>()) {
          channelByConv[c['conversation_id'] as String] = c;
        }
        // 2. Andere Mitglieder fuer DMs
        final allMembers = await sb
            .from('conversation_members')
            .select('conversation_id, user_id')
            .inFilter('conversation_id', convIds);
        final peerByConv = <String, List<String>>{};
        for (final m
            in (allMembers as List).whereType<Map<String, dynamic>>()) {
          final convId = m['conversation_id'] as String;
          final memUid = m['user_id'] as String;
          if (memUid == uid) continue;
          peerByConv.putIfAbsent(convId, () => []).add(memUid);
        }
        // 3. Profile-Batch-Lookup
        final allPeerIds = peerByConv.values.expand((l) => l).toSet().toList();
        final profileById = <String, Map<String, dynamic>>{};
        if (allPeerIds.isNotEmpty) {
          final profiles = await sb
              .from('profiles')
              .select('id, display_name, name, avatar_url, location')
              .inFilter('id', allPeerIds);
          for (final p in (profiles as List)
              .whereType<Map<String, dynamic>>()) {
            profileById[p['id'] as String] = p;
          }
        }
        // 4. Merge in result
        for (final row in result) {
          final convId = row['id'] as String;
          final channel = channelByConv[convId];
          if (channel != null) {
            row['channel'] = channel;
            row['display_title'] =
                '${channel['emoji'] ?? '💬'} ${channel['name']}';
            row['display_subtitle'] = channel['description'];
            row['is_channel'] = true;
            continue;
          }
          final peers = peerByConv[convId] ?? const [];
          if (peers.length == 1) {
            final p = profileById[peers.first];
            if (p != null) {
              row['peer_user_id'] = p['id'];
              row['peer_name'] = (p['display_name'] as String?) ??
                  (p['name'] as String?) ??
                  'Nachbar:in';
              row['peer_avatar_url'] = p['avatar_url'];
              row['peer_location'] = p['location'];
              row['display_title'] = row['peer_name'];
              row['display_subtitle'] = row['peer_location'];
              row['is_dm'] = true;
              continue;
            }
          }
          if (peers.length > 1) {
            row['display_title'] = (row['title'] as String?) ??
                '${peers.length + 1} Teilnehmer:innen';
            row['display_subtitle'] = null;
            row['is_group'] = true;
          } else {
            row['display_title'] =
                (row['title'] as String?) ?? 'Konversation';
          }
        }
      }
      result.sort((a, b) {
        // Explizit UTC normalisieren — DB liefert ISO mit "Z", aber
        // bei fehlendem Z parst Dart als local. .toUtc() fixt das.
        final ta = (DateTime.tryParse(
                    (a['updated_at'] ?? a['created_at']) as String? ?? '')?.toUtc() ??
                DateTime.utc(2000))
            .toUtc();
        final tb = (DateTime.tryParse(
                    (b['updated_at'] ?? b['created_at']) as String? ?? '')?.toUtc() ??
                DateTime.utc(2000))
            .toUtc();
        return tb.compareTo(ta);
      });
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// F1c (soft): Versteckt die Konversation nur fuer den Caller. Andere
  /// Teilnehmer sehen sie weiter. Sobald jemand wieder schreibt, taucht
  /// sie wieder auf (Realtime-Trigger setzt updated_at, get_or_create_dm
  /// resettet hidden_at beim naechsten Open).
  static Future<bool> hideDmForMe(String conversationId) async {
    try {
      final r = await sb.rpc<dynamic>('hide_dm_for_me',
          params: {'p_conversation_id': conversationId});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// F1c (hard): HARD DELETE der ganzen Konversation inkl. messages,
  /// reactions, pins, members (alles CASCADE). Wirkt fuer BEIDE.
  static Future<bool> deleteDmForBoth(String conversationId) async {
    try {
      final r = await sb.rpc<dynamic>('delete_dm_for_both',
          params: {'p_conversation_id': conversationId});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// F2 + Phase-1-BUG1: Startet eine 1:1-Konversation oder gibt existierende
  /// zurueck. Optional `postId` setzt den Post-Bezug auf der conversation
  /// (Chat-Header zeigt dann 'Bezug: [Post-Titel]').
  /// Setzt hidden_at vom Caller zurueck wenn vorher versteckt.
  /// Returns die conversation_id oder null bei Fehler.
  static Future<String?> getOrCreateDm(
    String otherUserId, {
    String? postId,
  }) async {
    try {
      final r = await sb.rpc<dynamic>('get_or_create_dm', params: {
        'p_other_user_id': otherUserId,
        if (postId != null) 'p_post_id': postId,
      });
      return r as String?;
    } catch (e, st) {
      debugPrint('[getOrCreateDm] failed: $e\n$st');
      return null;
    }
  }

  /// True wenn die Konversation mindestens eine Nachricht hat.
  static Future<bool> hasMessages(String conversationId) async {
    try {
      final rows = await sb
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Eigene Memberships mit last_read_at (fuer Unread-Aggregation).
  static Future<List<Map<String, dynamic>>> myMembershipsRead(
      String userId) async {
    try {
      final rows = await sb
          .from('conversation_members')
          .select('conversation_id, last_read_at')
          .eq('user_id', userId);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Mein `last_read_at` in dieser Konversation (für die „bis hier gelesen"-
  /// Markierung beim Öffnen). Null wenn keine Membership/kein Wert.
  static Future<DateTime?> myLastReadAt(String conversationId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('conversation_members')
          .select('last_read_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', uid)
          .maybeSingle();
      final raw = row?['last_read_at'] as String?;
      return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  /// Mitglieder einer Konversation inkl. Profil (fuer @-Mention-Autocomplete).
  static Future<List<Map<String, dynamic>>> members(
      String conversationId) async {
    try {
      final rows = await sb
          .from('conversation_members')
          .select('user_id, profiles!inner(id, display_name, avatar_url)')
          .eq('conversation_id', conversationId)
          .limit(100);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => Map<String, dynamic>.from(r['profiles'] as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Vanish-Mode-Einstellungen einer Konversation.
  static Future<({bool enabled, int seconds})> vanishSettings(
      String conversationId) async {
    try {
      final row = await sb
          .from('conversations')
          .select('vanish_mode_enabled, vanish_seconds')
          .eq('id', conversationId)
          .maybeSingle();
      return (
        enabled: row?['vanish_mode_enabled'] as bool? ?? false,
        seconds: (row?['vanish_seconds'] as num?)?.toInt() ?? 3600,
      );
    } catch (_) {
      return (enabled: false, seconds: 3600);
    }
  }

  /// Vanish-Mode setzen.
  static Future<void> setVanish({
    required String conversationId,
    required bool enabled,
    required int seconds,
  }) async {
    await sb.from('conversations').update({
      'vanish_mode_enabled': enabled,
      'vanish_seconds': seconds,
    }).eq('id', conversationId);
  }
}

class MessagesRepository {
  const MessagesRepository._();

  /// Realtime-Stream der Messages einer Conversation, sortiert aufsteigend.
  static Stream<List<Map<String, dynamic>>> watch(String conversationId) {
    // MEMORY-FIX: Descending + limit(200) → letzte 200 Messages.
    // Ohne Limit: Supabase .stream() lädt ALLE Messages einer Conversation
    // in den RAM und re-emittiert sie bei jeder neuen Nachricht vollständig.
    // Bei 5000 Nachrichten und 10 geöffneten Chats = 50 000 Rows im Speicher.
    // Nach dem Limit wird in Dart aufsteigend sortiert für korrekte Anzeige.
    return sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(200)
        .map((rows) {
          final list = rows.where((r) => r['deleted_at'] == null).toList()
            ..sort((a, b) {
              final ta = DateTime.tryParse(a['created_at'] as String? ?? '')?.toUtc() ??
                  DateTime(2000);
              final tb = DateTime.tryParse(b['created_at'] as String? ?? '')?.toUtc() ??
                  DateTime(2000);
              return ta.compareTo(tb);
            });
          return list;
        });
  }

  static Future<bool> send({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
      });
      // Touch conversation.updated_at fuer Sort-Order.
      await sb
          .from('conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', conversationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// System-Notiz in eine Konversation einfügen (z. B. [SYSTEM_NOTE:...]
  /// nach einem Call). Bewusst OHNE conversations.updated_at-Touch —
  /// System-Notizen sollen die Sortierung nicht nach oben spülen.
  static Future<void> insertSystemNote({
    required String conversationId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await sb.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': content,
    });
  }

  /// Letzte [limit] Nachrichten-Contents einer Konversation (neueste
  /// zuerst), für die Medien-Galerie. Nur content+created_at, nicht
  /// gelöschte. Best-effort, leere Liste bei Fehler.
  static Future<List<Map<String, dynamic>>> recentContents(
    String conversationId, {
    int limit = 500,
  }) async {
    try {
      final rows = await sb
          .from('messages')
          .select('content, created_at')
          .eq('conversation_id', conversationId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Letzte Nachrichten EINER Konversation von ANDEREN (fuer Unread).
  static Future<List<Map<String, dynamic>>> recentFromOthers({
    required String conversationId,
    required String excludeSenderId,
    int limit = 20,
  }) async {
    try {
      final rows = await sb
          .from('messages')
          .select('id, content, sender_id, created_at')
          .eq('conversation_id', conversationId)
          .neq('sender_id', excludeSenderId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Weitergeleitete Nachricht in eine Konversation einfuegen.
  static Future<void> forward({
    required String conversationId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await sb.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': content,
    });
  }

  /// Letzte 100 nicht-geloeschte Nachrichten fuer den Chat-Recap.
  static Future<List<Map<String, dynamic>>> recentForRecap(
      String conversationId) async {
    try {
      final rows = await sb
          .from('messages')
          .select('content, sender_id, created_at')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Eigene Nachricht editieren (nur eigene erlaubt — RLS).
  static Future<bool> edit({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await sb.from('messages').update({
        'content': newContent,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('[MessagesRepository.edit] failed: $e');
      return false;
    }
  }

  /// Eigene Nachricht soft-deleten (RLS auf sender_id = auth.uid()).
  /// Setzt content='' — funktioniert seit Mai 2026 weil messages_content_check
  /// jetzt empty erlaubt wenn deleted_at IS NOT NULL.
  static Future<bool> deleteMessage(String messageId) async {
    try {
      await sb.from('messages').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'content': '',
      }).eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('[MessagesRepository.deleteMessage] failed: $e');
      return false;
    }
  }

  /// Hard-DELETE alle Messages dieser DM-Conversation aus Supabase.
  /// Wirkt fuer BEIDE Teilnehmer (echte Loeschung, kein Soft-Delete).
  /// Returns Anzahl geloeschter Messages, oder null bei Fehler.
  static Future<int?> clearDmHistory(String conversationId) async {
    try {
      final result = await sb.rpc<dynamic>('clear_dm_history',
          params: {'p_conversation_id': conversationId});
      if (result is int) return result;
      if (result is num) return result.toInt();
      return 0;
    } catch (_) {
      return null;
    }
  }

  /// Pinned messages for a channel/conversation.
  /// 1:1 to web ChatView.tsx loadPinnedMessages.
  static Stream<List<Map<String, dynamic>>> watchPinnedMessages(
      String conversationId) {
    return sb
        .from('message_pins')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .limit(50)
        .map((rows) => rows
            .map<Map<String, dynamic>>((r) =>
                Map<String, dynamic>.from(r as Map))
            .toList());
  }

  /// Pin or unpin a message (admin/mod only — RLS enforced server-side).
  static Future<bool> togglePin({
    required String messageId,
    required String conversationId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('message_pins')
          .select('id')
          .eq('message_id', messageId)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('message_pins')
            .delete()
            .eq('id', existing['id'] as Object);
        return false;
      }
      await sb.from('message_pins').insert({
        'message_id': messageId,
        'conversation_id': conversationId,
        'pinned_by': uid,
      });
      return true;
    } catch (e) {
      debugPrint('[MessagesRepository.togglePin] failed: $e');
      return false;
    }
  }

  /// Channel announcements (admin pinned info banner).
  /// 1:1 to web ChatView.tsx loadAnnouncements.
  static Future<List<Map<String, dynamic>>> listAnnouncements(
      String conversationId) async {
    try {
      final rows = await sb
          .from('chat_announcements')
          .select('id, content, type, created_at, author_id')
          .eq('conversation_id', conversationId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(3);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Lookup einer Single-Message (z.B. fuer Reply-to-Quote-Anzeige).
  static Future<Map<String, dynamic>?> fetchById(String messageId) async {
    try {
      final row = await sb
          .from('messages')
          .select('id, sender_id, content, created_at')
          .eq('id', messageId)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markRead(String conversationId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .eq('conversation_id', conversationId);
    } catch (_) {}
  }

  /// Reaktion auf eine Message hinzufuegen/entfernen (Toggle).
  /// Schema: message_reactions(message_id, user_id, emoji).
  static Future<bool> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .eq('emoji', emoji)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('message_reactions')
            .delete()
            .eq('id', existing['id'] as Object);
        return true;
      }
      await sb.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': uid,
        'emoji': emoji,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Realtime: alle Reaktionen einer Conversation (joinable).
  static Stream<List<Map<String, dynamic>>> watchReactions(
      String conversationId) {
    // MEMORY-FIX: .eq() + .limit() hinzugefügt.
    // Vorher: kein Server-Filter → lädt ALLE message_reactions der gesamten
    // Datenbank in den Client, dann client-seitig gefiltert.
    // KRITISCH: Bei tausenden Usern und Reactions → massive OOM-Gefahr.
    return sb
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .limit(500)
        .map((rows) => rows.toList());
  }

  /// Live-Stream der last_read_at-Werte der anderen Mitglieder
  /// (fuer Read-Receipts: "Gelesen am ...").
  static Stream<DateTime?> watchPeerLastRead(String conversationId) {
    final uid = SupabaseService.currentUser?.id;
    return sb
        .from('conversation_members')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', conversationId)
        .limit(200)
        .map((rows) {
          final peers = rows.where((r) => r['user_id'] != uid);
          DateTime? latest;
          for (final p in peers) {
            final ts =
                DateTime.tryParse(p['last_read_at'] as String? ?? '')?.toUtc();
            if (ts != null && (latest == null || ts.isAfter(latest))) {
              latest = ts;
            }
          }
          return latest;
        });
  }
}

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ConversationsRepository.listMine();
});

// MEMORY-FIX: autoDispose — ohne autoDispose blieben geöffnete Chats mit
// ALLEN Messages im RAM (StreamProvider.family cached pro conversationId).
// 10 geöffnete Chats × 5000 Messages × ~400 Bytes = 20 MB blockiert.
// autoDispose gibt den Provider frei sobald kein Widget mehr lauscht.
final messagesStreamProvider =
    StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
        (ref, conversationId) {
  return MessagesRepository.watch(conversationId);
});

/// Stream der zuletzt-gelesen-Zeit der anderen Mitglieder (fuer Read-Receipts).
// MEMORY-FIX: autoDispose — wie messagesStreamProvider, sonst bleibt
// pro geöffnetem Chat ein Supabase-Realtime-Channel für immer offen.
final peerLastReadProvider =
    StreamProvider.family.autoDispose<DateTime?, String>((ref, conversationId) {
  return MessagesRepository.watchPeerLastRead(conversationId);
});
