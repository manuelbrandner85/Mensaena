import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Ermittelt fuer eine Conversation-ID den korrekten Anzeige-Kontext:
///   - Wenn an einen `chat_channels`-Eintrag verknuepft: Channel-Info
///     (name, emoji, description, is_default, is_locked)
///   - Sonst (echter DM): Profile des anderen Mitglieds aus
///     `conversation_members` join `profiles`
/// Beendet das Problem "Konversation"/"Chat" als generischer Titel.
class ChatContextService {
  const ChatContextService._();

  static Future<ChatContext> resolve(String conversationId) async {
    // 1) Channel-Lookup
    try {
      final channel = await sb
          .from('chat_channels')
          .select(
              'id, name, description, emoji, slug, is_default, is_locked')
          .eq('conversation_id', conversationId)
          .maybeSingle();
      if (channel != null) {
        return ChatContext(
          kind: ChatKind.channel,
          title: channel['name'] as String? ?? 'Kanal',
          emoji: channel['emoji'] as String? ?? '💬',
          subtitle: channel['description'] as String?,
          isLocked: (channel['is_locked'] as bool?) ?? false,
          slug: channel['slug'] as String?,
        );
      }
    } catch (_) {}

    // 2) Conversation-Title-Lookup (z.B. Gruppen/Marktplatz-Threads)
    String? convTitle;
    try {
      final conv = await sb
          .from('conversations')
          .select('title, type')
          .eq('id', conversationId)
          .maybeSingle();
      if (conv != null) convTitle = conv['title'] as String?;
    } catch (_) {}

    // 3) Partner-Profile-Lookup (anderes Mitglied)
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      return ChatContext(
          kind: ChatKind.unknown,
          title: convTitle ?? 'Chat',
          emoji: '💬');
    }
    try {
      final members = await sb
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId);
      final memberIds = (members as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['user_id'] as String)
          .where((id) => id != uid)
          .toList();
      if (memberIds.isEmpty) {
        return ChatContext(
            kind: ChatKind.group,
            title: convTitle ?? 'Gruppe',
            emoji: '👥');
      }
      if (memberIds.length == 1) {
        final p = await sb
            .from('profiles')
            .select('id, display_name, name, avatar_url, location')
            .eq('id', memberIds.first)
            .maybeSingle();
        if (p != null) {
          return ChatContext(
            kind: ChatKind.dm,
            partnerId: p['id'] as String,
            title: (p['display_name'] as String?) ??
                (p['name'] as String?) ??
                'Nachbar:in',
            subtitle: p['location'] as String?,
            avatarUrl: p['avatar_url'] as String?,
            emoji: '💬',
          );
        }
      }
      // Gruppen-Chat mit mehreren Teilnehmern
      return ChatContext(
        kind: ChatKind.group,
        title: convTitle ?? '${memberIds.length + 1} Teilnehmer:innen',
        emoji: '👥',
      );
    } catch (_) {}

    return ChatContext(
        kind: ChatKind.unknown,
        title: convTitle ?? 'Chat',
        emoji: '💬');
  }
}

enum ChatKind { channel, dm, group, unknown }

class ChatContext {
  const ChatContext({
    required this.kind,
    required this.title,
    required this.emoji,
    this.subtitle,
    this.partnerId,
    this.avatarUrl,
    this.isLocked = false,
    this.slug,
  });

  final ChatKind kind;
  final String title;
  final String emoji;
  final String? subtitle;
  final String? partnerId; // nur bei DMs
  final String? avatarUrl;
  final bool isLocked; // Channels mit Lock
  final String? slug; // Channel-Slug
}
