import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../config/theme/cinema_accents.dart';
import '../../../providers/cinema_provider.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../services/chat_context_service.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/haptics.dart';
import '../../../services/presence_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/voice_recorder_service.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import 'chat_input_bar.dart';
import 'chat_live_banner.dart';
import 'chat_message_bubble.dart';
import 'chat_typing_indicator.dart';

/// SKILL: mensaena-features
/// Chat-Screen mit Realtime-Messages via Supabase Stream.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  RealtimeChannel? _typingChannel;
  bool _peerTyping = false;
  DateTime _lastTypingBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  ChatContext? _context;
  String? _activeCallId;
  String? _activeStreamRoom;
  Map<String, dynamic>? _replyTo;
  // @-Mention state (1:1 to Web ChatView.tsx mention-autocomplete)
  List<Map<String, dynamic>> _mentionSuggestions = const [];
  String? _mentionQuery;
  Timer? _mentionDebounce;
  // In-Chat search state (1:1 to Web ChatView.tsx message-search)
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    MessagesRepository.markRead(widget.conversationId);
    _setupPresence();
    _ctrl.addListener(_onTextChanged);
    _loadContext();
  }

  Future<void> _loadContext() async {
    final ctx =
        await ChatContextService.resolve(widget.conversationId);
    if (mounted) setState(() => _context = ctx);
  }

  // Call/Stream-Buttons sind jetzt im _ChatTopBar integriert (eleganter
  // statt grosser FAB unten rechts). Die Action-Handler bleiben unten.

  Future<void> _startCall() async {
    final ctx = _context;
    if (ctx == null) {
      _showCallError('Chat lädt noch …');
      return;
    }
    if (ctx.kind != ChatKind.dm) {
      _showCallError('Anrufe nur in privaten Chats möglich');
      return;
    }
    if (ctx.partnerId == null) {
      _showCallError('Gesprächspartner nicht gefunden');
      return;
    }
    final result = await DmCallService.start(
      conversationId: widget.conversationId,
      calleeId: ctx.partnerId!,
    );
    if (!mounted) return;
    if (!result.success || result.callId == null || result.roomName == null) {
      _showCallError(result.errorReason ?? 'Anruf konnte nicht gestartet werden');
      return;
    }
    setState(() => _activeCallId = result.callId);
    final peer = Uri.encodeComponent(ctx.title);
    final room = Uri.encodeComponent(result.roomName!);
    context.push('/dashboard/call/${result.callId}?room=$room&peer=$peer');
  }

  void _showCallError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Row(children: [
        const Icon(LucideIcons.phoneOff, size: 16, color: AppColors.herzrot),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: AppTypography.body(size: 13, color: AppColors.ink))),
      ]),
    ));
  }

  Future<void> _startStream() async {
    final ctx = _context;
    if (ctx == null || ctx.kind != ChatKind.channel || ctx.slug == null) {
      return;
    }
    final room = await LiveStreamService.startChannelStream(
      conversationId: widget.conversationId,
      channelSlug: ctx.slug!,
      topic: 'Live im Kanal ${ctx.title}',
    );
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('chat.livestreamFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    setState(() => _activeStreamRoom = room);
    final title = Uri.encodeComponent(ctx.title);
    final r = Uri.encodeComponent(room);
    context.push('/dashboard/live/$r?title=$title&host=1');
  }

  void _setupPresence() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    _typingChannel = sb.channel('chat:${widget.conversationId}');
    _typingChannel!
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final from = payload['from'] as String?;
          final isTyping = payload['typing'] as bool? ?? false;
          if (from == null || from == uid) return;
          if (!mounted) return;
          setState(() => _peerTyping = isTyping);
          if (isTyping) {
            Future.delayed(const Duration(seconds: 4), () {
              if (!mounted) return;
              setState(() => _peerTyping = false);
            });
          }
        },
      )
      ..subscribe();
  }

  void _onTextChanged() {
    final uid = SupabaseService.currentUser?.id;
    // Typing broadcast
    if (uid != null && _typingChannel != null) {
      final now = DateTime.now();
      if (now.difference(_lastTypingBroadcast) >=
          const Duration(milliseconds: 1500)) {
        _lastTypingBroadcast = now;
        _typingChannel!.sendBroadcastMessage(
          event: 'typing',
          payload: {'from': uid, 'typing': _ctrl.text.isNotEmpty},
        );
      }
    }
    // @-Mention detection (debounced 150ms to keep input responsive)
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 150), _detectMention);
  }

  /// Detects an active '@xxx' token at the cursor position and triggers
  /// a profile lookup. Closes suggestions if no '@' or space after it.
  void _detectMention() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _closeMentionSuggestions();
      return;
    }
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) {
      _closeMentionSuggestions();
      return;
    }
    // Token must not have whitespace between @ and cursor.
    final token = before.substring(atIdx + 1);
    if (token.contains(' ') || token.contains('\n')) {
      _closeMentionSuggestions();
      return;
    }
    _mentionQuery = token;
    _loadMentionSuggestions(token);
  }

  Future<void> _loadMentionSuggestions(String query) async {
    try {
      // Empty query → show recent contacts (skip for now, just hide)
      if (query.isEmpty) {
        if (mounted) setState(() => _mentionSuggestions = const []);
        return;
      }
      final rows = await sb
          .from('profiles')
          .select('id, name, display_name, nickname, avatar_url')
          .or('nickname.ilike.$query%,name.ilike.$query%,display_name.ilike.$query%')
          .limit(6);
      if (!mounted) return;
      setState(() => _mentionSuggestions =
          (rows as List).whereType<Map<String, dynamic>>().toList());
    } catch (_) {
      if (mounted) setState(() => _mentionSuggestions = const []);
    }
  }

  void _closeMentionSuggestions() {
    if (_mentionSuggestions.isEmpty && _mentionQuery == null) return;
    if (mounted) {
      setState(() {
        _mentionSuggestions = const [];
        _mentionQuery = null;
      });
    }
  }

  /// Inserts the selected mention into the composer text and closes
  /// the suggestion list. Replaces only the '@token' substring at cursor.
  void _insertMention(Map<String, dynamic> profile) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) return;
    final mentionName =
        (profile['nickname'] as String?)?.replaceAll(' ', '_') ??
            (profile['display_name'] as String?)?.replaceAll(' ', '_') ??
            (profile['name'] as String?)?.replaceAll(' ', '_') ??
            'user';
    final newText = '${before.substring(0, atIdx)}@$mentionName $after';
    final newCursor = atIdx + mentionName.length + 2; // @ + name + space
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _closeMentionSuggestions();
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _searchCtrl.dispose();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    // BUG-FIX #13: Channel unsubscribe + removeChannel — sonst bleibt
    // RealtimeChannel im Supabase-Client-Pool, fuehrt zu Memory-Leak +
    // doppelten typing-Broadcasts bei schnellem Chat-Wechsel.
    final ch = _typingChannel;
    if (ch != null) {
      try {
        ch.unsubscribe();
        sb.removeChannel(ch);
      } catch (_) {}
    }
    _typingChannel = null;
    super.dispose();
  }

  /// Sends a voice-message as `[VOICE:url:seconds]` text.
  /// The bubble parses this on render and shows VoiceMessageBubble.
  Future<void> _sendVoice(String url, int durationSeconds) async {
    final encoded = VoiceRecorderService.encodeMessage(
        url: url, durationSeconds: durationSeconds);
    await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: encoded,
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    Haptics.tap();
    final reply = _replyTo;
    final ok = await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: text,
      replyToId: reply?['id'] as String?,
    );
    if (!mounted) return;
    if (ok) {
      // Erst nach Success clearen — bei Fail behaelt der User den Text
      // und kann nochmal senden.
      _ctrl.clear();
      setState(() => _replyTo = null);
    } else {
      unawaited(Haptics.error());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('chat.messageNotSent'.tr())),
      );
    }
  }

  Future<void> _editMessage(String id, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('chat.editMessage'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == currentContent) {
      return;
    }
    await MessagesRepository.edit(messageId: id, newContent: newText);
  }

  Future<void> _deleteMessage(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('chat.deleteMessageTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text('chat.deleteMessageBody'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await MessagesRepository.deleteMessage(id);
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(messagesStreamProvider(widget.conversationId));
    final peerReadAsync =
        ref.watch(peerLastReadProvider(widget.conversationId));
    final titleText = _context == null
        ? 'Chat'
        : '${_context!.emoji} ${_context!.title}';
    return DashboardScaffold(
      title: titleText,
      currentRoute: '/dashboard/chat',
      body: SafeArea(
        child: Column(
          children: [
            // Eleganter Chat-Top-Bar: Avatar/Emoji + Name + Action-Icons.
            // Ersetzt den grossen FAB unten rechts.
            _ChatTopBar(
              context: _context,
              activeCallId: _activeCallId,
              activeStreamRoom: _activeStreamRoom,
              searchOpen: _searchOpen,
              searchCtrl: _searchCtrl,
              onToggleSearch: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                }
              }),
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onStartCall: _startCall,
              onCancelCall: () async {
                if (_activeCallId == null) return;
                await DmCallService.cancel(_activeCallId!);
                if (mounted) setState(() => _activeCallId = null);
              },
              onStartStream: _startStream,
              onEndStream: () async {
                if (_activeStreamRoom == null) return;
                await LiveStreamService.endChannelStream(_activeStreamRoom!);
                if (mounted) setState(() => _activeStreamRoom = null);
              },
            ),
            // Live-Banner — wenn jemand im Channel live ist, koennen
            // alle anderen beitreten.
            if (_context?.kind == ChatKind.channel)
              ChatLiveRoomBanner(
                conversationId: widget.conversationId,
                channelTitle: _context!.title,
                myUserId: SupabaseService.currentUser?.id,
              ),
            // Pinned-Messages-Panel — nur in Channels
            if (_context?.kind == ChatKind.channel)
              ChatPinnedMessagesPanel(conversationId: widget.conversationId),
            Expanded(
              child: stream.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Fehler: $e',
                    style: AppTypography.caption(),
                  ),
                ),
                data: (msgsRaw) {
                  // In-Chat-Search: lokaler Filter ueber content
                  final q = _searchQuery.trim().toLowerCase();
                  final msgs = q.isEmpty
                      ? msgsRaw
                      : msgsRaw.where((m) {
                          final c = (m['content'] as String? ?? '')
                              .toLowerCase();
                          return c.contains(q);
                        }).toList();
                  if (msgs.isEmpty) {
                    return Center(
                      child: Text(
                        q.isEmpty
                            ? 'Schreib die erste Nachricht.'
                            : 'Keine Treffer für „$_searchQuery".',
                        style: AppTypography.caption(),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(
                        _scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  final peerLastRead = peerReadAsync.value;
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      final mine =
                          m['sender_id'] == SupabaseService.currentUser?.id;
                      final isLast = i == msgs.length - 1;
                      bool readByPeer = false;
                      if (mine && peerLastRead != null) {
                        final ts = DateTime.tryParse(
                            m['created_at'] as String? ?? '');
                        readByPeer =
                            ts != null && !ts.isAfter(peerLastRead);
                      }
                      return ChatMessageBubble(
                        json: m,
                        mine: mine,
                        showReadReceipt: mine && isLast,
                        readByPeer: readByPeer,
                        conversationId: widget.conversationId,
                        onReact: (emoji) =>
                            MessagesRepository.toggleReaction(
                          messageId: m['id'] as String,
                          emoji: emoji,
                        ),
                        onReply: () => setState(() => _replyTo = m),
                        onEdit: mine
                            ? () => _editMessage(
                                  m['id'] as String,
                                  (m['content'] as String?) ?? '',
                                )
                            : null,
                        onDelete: mine
                            ? () => _deleteMessage(m['id'] as String)
                            : null,
                        // Pin only for channels (DMs have no admin-mod model)
                        onPin: _context?.kind == ChatKind.channel
                            ? () async {
                                final pinned = await MessagesRepository
                                    .togglePin(
                                  messageId: m['id'] as String,
                                  conversationId: widget.conversationId,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surface,
                                    content: Text(
                                      pinned
                                          ? '📌 Nachricht angepinnt.'
                                          : 'Pin entfernt.',
                                      style: AppTypography.body(
                                          size: 13, color: AppColors.ink),
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (_peerTyping)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                color: AppColors.deep,
                child: Row(
                  children: [
                    const ChatTypingDots(),
                    const SizedBox(width: 8),
                    Text('schreibt…',
                        style: AppTypography.body(
                            size: 11, color: AppColors.mute)),
                  ],
                ),
              ),
            if (_replyTo != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                decoration: BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.08),
                  border: Border(
                    top: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      color: AppColors.bronze,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('chat.replyTo'.tr(),
                              style: AppTypography.label(
                                  size: 9, color: AppColors.bronzeSoft)),
                          const SizedBox(height: 2),
                          Text(
                            (_replyTo!['content'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(LucideIcons.x,
                          size: 14, color: AppColors.mute),
                    ),
                  ],
                ),
              ),
            // @-Mention-Vorschlaege (max 6 Treffer, scrollable falls noetig)
            if (_mentionSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.line),
                    bottom: BorderSide(color: AppColors.line),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (context, i) {
                    final p = _mentionSuggestions[i];
                    final name = (p['display_name'] as String?) ??
                        (p['name'] as String?) ??
                        'Nutzer:in';
                    final nick = p['nickname'] as String?;
                    final avatarUrl = p['avatar_url'] as String?;
                    return InkWell(
                      onTap: () => _insertMention(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            if (avatarUrl != null)
                              CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                                imageBuilder: (_, img) => CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.elevated,
                                  backgroundImage: img,
                                ),
                                placeholder: (_, __) => const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.elevated,
                                ),
                                errorWidget: (_, __, ___) => CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.elevated,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: AppTypography.mono(
                                        size: 11,
                                        color: AppColors.bronze),
                                  ),
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.elevated,
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.mono(
                                      size: 11,
                                      color: AppColors.bronze),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: AppTypography.body(
                                          size: 13,
                                          color: AppColors.ink,
                                          weight: FontWeight.w600)),
                                  if (nick != null && nick.isNotEmpty)
                                    Text('@$nick',
                                        style: AppTypography.body(
                                            size: 11,
                                            color: AppColors.mute)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ChatInputBar(
              controller: _ctrl,
              conversationId: widget.conversationId,
              onSend: _send,
              onVoiceUploaded: _sendVoice,
              onTextChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Eleganter Chat-Top-Bar — Avatar/Emoji + Name + Presence + Action-Icons.
// Bleibt im Haupt-Screen weil eng mit Call/Stream-State + Search-State
// gekoppelt; ein eigenes File haette nur Props-Forwarding.
// ─────────────────────────────────────────────────────────────
class _ChatTopBar extends ConsumerStatefulWidget {
  const _ChatTopBar({
    required this.context,
    required this.activeCallId,
    required this.activeStreamRoom,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onStartCall,
    required this.onCancelCall,
    required this.onStartStream,
    required this.onEndStream,
  });

  final ChatContext? context;
  final String? activeCallId;
  final String? activeStreamRoom;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onStartCall;
  final Future<void> Function() onCancelCall;
  final Future<void> Function() onStartStream;
  final Future<void> Function() onEndStream;

  @override
  ConsumerState<_ChatTopBar> createState() => _ChatTopBarState();
}

class _ChatTopBarState extends ConsumerState<_ChatTopBar> {
  @override
  Widget build(BuildContext context) {
    final ctx = widget.context;
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final accent = CinemaAccents.hue(phase);
    final isDm = ctx?.kind == ChatKind.dm;
    final isChannel = ctx?.kind == ChatKind.channel;
    final isOnline = isDm && ctx?.partnerId != null
        ? (ref.watch(onlineUsersProvider).value?.contains(ctx!.partnerId!) ??
            false)
        : false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface.withValues(alpha: 0.35),
            AppColors.surface.withValues(alpha: 0.0),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Row 1 — Avatar/Emoji + Name/Subtitle + Action-Icons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                _LeadingBadge(ctx: ctx, isOnline: isOnline, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ctx?.title ?? 'Chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _subtitle(ctx, isOnline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          size: 9,
                          color: isOnline
                              ? AppColors.lebenSoft
                              : AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action-Icons je nach Kontext
                if (isDm)
                  _ActionIcon(
                    icon: widget.activeCallId != null
                        ? LucideIcons.phoneOff
                        : LucideIcons.phone,
                    label: widget.activeCallId != null
                        ? 'Auflegen'
                        : 'Anrufen',
                    color: widget.activeCallId != null
                        ? AppColors.herzrot
                        : AppColors.leben,
                    onTap: widget.activeCallId != null
                        ? () async => widget.onCancelCall()
                        : () async => widget.onStartCall(),
                    pulse: widget.activeCallId != null,
                  ),
                if (isChannel)
                  _ActionIcon(
                    icon: widget.activeStreamRoom != null
                        ? LucideIcons.videoOff
                        : LucideIcons.video,
                    label: widget.activeStreamRoom != null
                        ? 'Stream beenden'
                        : 'Livestream starten',
                    color: widget.activeStreamRoom != null
                        ? AppColors.herzrot
                        : AppColors.bronze,
                    onTap: widget.activeStreamRoom != null
                        ? () async => widget.onEndStream()
                        : () async => widget.onStartStream(),
                    pulse: widget.activeStreamRoom != null,
                  ),
                _ActionIcon(
                  icon: widget.searchOpen
                      ? LucideIcons.x
                      : LucideIcons.search,
                  label: widget.searchOpen ? 'Suche schließen' : 'Suchen',
                  color: widget.searchOpen ? accent : AppColors.mute,
                  onTap: () async => widget.onToggleSearch(),
                ),
              ],
            ),
          ),
          // Slide-in Search-Field
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: widget.searchOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      controller: widget.searchCtrl,
                      autofocus: true,
                      onChanged: widget.onSearchChanged,
                      style: AppTypography.body(
                          size: 13, color: AppColors.ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.elevated,
                        prefixIcon: const Icon(LucideIcons.search,
                            size: 14, color: AppColors.mute),
                        hintText: 'chat.searchMessages'.tr(),
                        hintStyle: AppTypography.body(
                            size: 12, color: AppColors.mute),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: accent, width: 1.5),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  String _subtitle(ChatContext? ctx, bool isOnline) {
    if (ctx == null) return '';
    if (ctx.kind == ChatKind.dm) {
      return isOnline ? 'Online' : 'Offline';
    }
    if (ctx.kind == ChatKind.channel) {
      return ctx.subtitle ?? 'Community-Kanal';
    }
    if (ctx.kind == ChatKind.group) return 'Gruppe';
    return '';
  }
}

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({
    required this.ctx,
    required this.isOnline,
    required this.accent,
  });

  final ChatContext? ctx;
  final bool isOnline;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = ctx?.avatarUrl != null && ctx!.avatarUrl!.isNotEmpty;
    final emoji = ctx?.emoji ?? '💬';
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasAvatar
                ? null
                : RadialGradient(colors: [
                    accent.withValues(alpha: 0.30),
                    accent.withValues(alpha: 0.10),
                  ]),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.20),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: hasAvatar
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: ctx!.avatarUrl!,
                    fadeInDuration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.elevated,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.elevated,
                      alignment: Alignment.center,
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                )
              : Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.leben,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.voidColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.pulse = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final btn = Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: pulse ? 0.22 : 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.40),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
    if (!pulse) return btn;
    return PulseBloom(
      color: color,
      radius: 18,
      minIntensity: 0.4,
      maxIntensity: 0.85,
      child: btn,
    );
  }
}
