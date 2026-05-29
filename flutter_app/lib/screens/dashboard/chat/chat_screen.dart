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
import '../../../services/conversation_mute_service.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/haptics.dart';
import '../../../services/presence_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/voice_recorder_service.dart';
import '../../../widgets/chat/forward_message_sheet.dart';
import '../../../widgets/chat/mentions_autocomplete.dart';
import '../../../widgets/chat/vanish_mode_banner.dart';
import '../../../widgets/chat/vanish_mode_sheet.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/video_preview_modal.dart';
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
  Timer? _peerTypingResetTimer;
  bool _peerTyping = false;
  DateTime _lastTypingBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  ChatContext? _context;
  String? _activeCallId;
  String? _activeStreamRoom;
  Map<String, dynamic>? _replyTo;
  // Optimistic Outbox: lokal eingefuegte Messages, die noch nicht via
  // Realtime-Stream zurueckgekommen sind. Werden gemerged + dedupliziert
  // (durch content + sender_id) im List-Builder. Bubble rendert mit
  // 60% Opacity solange noch pending.
  final List<Map<String, dynamic>> _pendingOutgoing =
      <Map<String, dynamic>>[];
  // @-Mention state (1:1 to Web ChatView.tsx mention-autocomplete)
  List<Map<String, dynamic>> _mentionSuggestions = const [];
  String? _mentionQuery;
  Timer? _mentionDebounce;
  // In-Chat search state (1:1 to Web ChatView.tsx message-search)
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  // Snapshot des last_read_at-Werts BEIM OEFFNEN — danach faengt
  // markRead() bereits zu aktualisieren an, daher merken wir den
  // Ausgangswert fuer den Unread-Divider (#3).
  DateTime? _myLastReadAtOpen;

  @override
  void initState() {
    super.initState();
    _captureLastReadAtOpen();
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


  Future<void> _startCall({String callType = 'audio'}) async {
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
    // Video: kurzes Camera-Preview-Sheet (Permission + Mic-Check).
    // Audio: sofort starten — der Vollscreen-Call-Screen hat eigene
    // Cancel/Hang-up-Buttons, ein extra Confirm-Dialog wäre 1× Tap zu viel.
    if (callType == 'video') {
      final ok = await VideoPreviewModal.show(context, peerName: ctx.title);
      if (!ok || !mounted) return;
    }
    final result = await DmCallService.start(
      conversationId: widget.conversationId,
      calleeId: ctx.partnerId!,
      callType: callType,
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
          // Cancellable Timer statt free-floating Future.delayed —
          // jeder neue typing-Event resettet die Auto-Off-Frist sauber.
          _peerTypingResetTimer?.cancel();
          setState(() => _peerTyping = isTyping);
          if (isTyping) {
            _peerTypingResetTimer = Timer(const Duration(seconds: 4), () {
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

  // Aktiver Query-Token gegen out-of-order responses: wenn User waehrend
  // einer noch-pending Query weiter tippt, sehen wir nach await ob die
  // query noch die aktuelle ist — sonst wegwerfen.
  String _activeMentionQuery = '';

  Future<void> _loadMentionSuggestions(String query) async {
    _activeMentionQuery = query;
    try {
      if (query.isEmpty) {
        if (mounted) setState(() => _mentionSuggestions = const []);
        return;
      }
      final rows = await sb
          .from('profiles')
          .select('id, name, display_name, nickname, avatar_url')
          .or('nickname.ilike.$query%,name.ilike.$query%,display_name.ilike.$query%')
          .limit(6);
      // Out-of-order-Guard: nur uebernehmen wenn query immer noch aktuell.
      if (!mounted || query != _activeMentionQuery) return;
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
    _peerTypingResetTimer?.cancel();
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
  /// Liest last_read_at vor markRead aus, damit der Unread-Divider die
  /// korrekte Stelle anzeigt (sonst waere die Markierung schon vor dem
  /// ersten Frame ueberschrieben).
  Future<void> _captureLastReadAtOpen() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final row = await sb
          .from('conversation_members')
          .select('last_read_at')
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', uid)
          .maybeSingle();
      final raw = row?['last_read_at'] as String?;
      if (raw != null && mounted) {
        setState(() => _myLastReadAtOpen = DateTime.tryParse(raw)?.toUtc());
      }
    } catch (_) {/* fail-silent */}
  }

  /// DM-Chat-History komplett aus DB loeschen. Wirkt fuer BEIDE Teilnehmer
  /// (HARD DELETE via clear_dm_history RPC mit Membership-Check).
  Future<void> _clearDmHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('chat.clearHistoryConfirmTitle'.tr(),
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text('chat.clearHistoryConfirmBody'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.inkSoft, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('chat.clearHistoryConfirmAction'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final count =
        await MessagesRepository.clearDmHistory(widget.conversationId);
    if (!mounted) return;
    // Supabase Realtime DELETE-Events propagieren bei .stream() nicht
    // immer zuverlaessig (siehe https://github.com/supabase/supabase/issues).
    // Provider invalidieren → fresh re-subscribe + initial-query holt
    // den leeren State garantiert.
    if (count != null && count > 0) {
      ref.invalidate(messagesStreamProvider(widget.conversationId));
      ref.invalidate(peerLastReadProvider(widget.conversationId));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        count != null
            ? 'chat.clearHistoryOk'.tr(namedArgs: {'count': '$count'})
            : 'chat.clearHistoryFailed'.tr(),
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  Future<void> _sendVoice(String url, int durationSeconds) async {
    final encoded = VoiceRecorderService.encodeMessage(
        url: url, durationSeconds: durationSeconds);
    await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: encoded,
    );
  }

  bool _sending = false;

  Future<void> _send() async {
    // Lock: Spam-Tap auf Send → nur einer in flight.
    if (_sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    Haptics.tap();
    final reply = _replyTo;
    final replyId = reply?['id'] as String?;
    final myUid = SupabaseService.currentUser?.id;
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    // Optimistic: TextField sofort leeren, fake-Message in der Liste
    // anzeigen. So fuehlt sich das Senden instant an, auch wenn der
    // RPC + Realtime-Roundtrip 150-400ms braucht.
    setState(() {
      _sending = true;
      _pendingOutgoing.add({
        'id': tempId,
        'sender_id': myUid,
        'content': text,
        'reply_to_id': replyId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        '_pending': true,
      });
      _ctrl.clear();
      _replyTo = null;
    });

    final ok = await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: text,
      replyToId: replyId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      // Rollback: pending-Bubble entfernen, Text restaurieren.
      setState(() {
        _pendingOutgoing.removeWhere((m) => m['id'] == tempId);
        _ctrl.text = text;
      });
      unawaited(Haptics.error());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('chat.messageNotSent'.tr())),
      );
    }
    // Erfolg: pending bleibt drin, wird vom naechsten Stream-Tick
    // entfernt sobald die echte Message via Realtime ankommt
    // (Dedupe-Logik im data-Builder).
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
    final ok =
        await MessagesRepository.edit(messageId: id, newContent: newText);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'chat.edited'.tr() : 'chat.editFailed'.tr(),
        style: AppTypography.body(
            size: 13,
            color: ok ? AppColors.ink : AppColors.herzrotWarm),
      ),
    ));
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
    final ok = await MessagesRepository.deleteMessage(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'chat.deleted'.tr() : 'chat.deleteFailed'.tr(),
        style: AppTypography.body(
            size: 13,
            color: ok ? AppColors.ink : AppColors.herzrotWarm),
      ),
    ));
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
              conversationId: widget.conversationId,
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
              onStartCall: () => _startCall(callType: 'audio'),
              onStartVideoCall: () => _startCall(callType: 'video'),
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
              onClearDmHistory: _clearDmHistory,
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
            VanishModeBanner(conversationId: widget.conversationId),
            Expanded(
              child: stream.when(
                loading: () => const _ChatBubbleSkeleton(count: 6),
                error: (e, _) => Center(
                  child: Text(
                    'Fehler: $e',
                    style: AppTypography.caption(),
                  ),
                ),
                data: (msgsRaw) {
                  // Optimistic-Dedupe: filtere _pendingOutgoing-Eintraege
                  // raus, die jetzt schon im Stream-Result enthalten sind
                  // (gleicher Sender + gleicher Content). Cleanup im
                  // State erfolgt post-frame damit setState() nicht im
                  // Build-Cycle laeuft.
                  final pending = _pendingOutgoing
                      .where((p) => !msgsRaw.any((m) =>
                          m['sender_id'] == p['sender_id'] &&
                          m['content'] == p['content']))
                      .toList();
                  if (pending.length != _pendingOutgoing.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _pendingOutgoing.removeWhere((p) => msgsRaw.any((m) =>
                          m['sender_id'] == p['sender_id'] &&
                          m['content'] == p['content']));
                    });
                  }
                  final combined = pending.isEmpty
                      ? msgsRaw
                      : <Map<String, dynamic>>[...msgsRaw, ...pending];
                  // In-Chat-Search: lokaler Filter ueber content
                  final q = _searchQuery.trim().toLowerCase();
                  final msgs = q.isEmpty
                      ? combined
                      : combined.where((m) {
                          final c = (m['content'] as String? ?? '')
                              .toLowerCase();
                          return c.contains(q);
                        }).toList();
                  if (msgs.isEmpty) {
                    return _ChatEmptyState(
                      isSearch: q.isNotEmpty,
                      searchQuery: _searchQuery,
                      isChannel: _context?.kind == ChatKind.channel,
                      channelTitle: _context?.title,
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
                  // Erster ungelesener Index fuer Unread-Divider (#3).
                  // Zeigt rote Linie ueber der ersten Nachricht die nach
                  // unserem last-read von einem anderen User kam.
                  final myUid = SupabaseService.currentUser?.id;
                  int firstUnreadIdx = -1;
                  final myLastRead = _myLastReadAtOpen;
                  if (myLastRead != null) {
                    for (int i = 0; i < msgs.length; i++) {
                      final m = msgs[i];
                      if (m['sender_id'] == myUid) continue;
                      final ts = DateTime.tryParse(
                          m['created_at'] as String? ?? '');
                      if (ts != null && ts.isAfter(myLastRead)) {
                        firstUnreadIdx = i;
                        break;
                      }
                    }
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      final mine = m['sender_id'] == myUid;
                      final isLast = i == msgs.length - 1;
                      bool readByPeer = false;
                      if (mine && peerLastRead != null) {
                        final ts = DateTime.tryParse(
                            m['created_at'] as String? ?? '');
                        readByPeer =
                            ts != null && !ts.isAfter(peerLastRead);
                      }
                      // Day-Separator (#1) zeigen wenn:
                      // - erste Nachricht ODER
                      // - vorherige Nachricht an einem anderen Tag war.
                      final mAt = (DateTime.tryParse(
                                  m['created_at'] as String? ?? '') ??
                              DateTime.now())
                          .toLocal();
                      final prevDay = i == 0
                          ? null
                          : (DateTime.tryParse(
                                      msgs[i - 1]['created_at'] as String? ??
                                          '') ??
                                  DateTime.now())
                              .toLocal();
                      final showDayHeader = prevDay == null ||
                          prevDay.year != mAt.year ||
                          prevDay.month != mAt.month ||
                          prevDay.day != mAt.day;
                      final showUnreadDivider = i == firstUnreadIdx;
                      // #2 Clustering: vorherige Message vom selben Sender,
                      // gleicher Tag, < 60s Diff, KEIN Day-Header und KEIN
                      // Unread-Divider dazwischen.
                      bool clustered = false;
                      if (i > 0 && !showDayHeader && !showUnreadDivider) {
                        final prev = msgs[i - 1];
                        if (prev['sender_id'] == m['sender_id']) {
                          final prevAt = DateTime.tryParse(
                              prev['created_at'] as String? ?? '');
                          if (prevAt != null) {
                            clustered =
                                mAt.difference(prevAt.toLocal()).inSeconds < 60;
                          }
                        }
                      }
                      final isPending = m['_pending'] == true;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDayHeader) _DaySeparator(date: mAt),
                          if (showUnreadDivider) const _UnreadDivider(),
                          Opacity(
                            opacity: isPending ? 0.55 : 1.0,
                            child: ChatMessageBubble(
                        json: m,
                        mine: mine,
                        clustered: clustered,
                        showReadReceipt: mine && isLast,
                        readByPeer: readByPeer,
                        conversationId: widget.conversationId,
                        onReact: (emoji) =>
                            MessagesRepository.toggleReaction(
                          messageId: m['id'] as String,
                          emoji: emoji,
                        ),
                        onReply: () => setState(() => _replyTo = m),
                        onForward: () => ForwardMessageSheet.show(
                          context,
                          originalContent:
                              (m['content'] as String?) ?? '',
                          fromConversationId: widget.conversationId,
                        ),
                        onEdit: mine
                            ? () => _editMessage(
                                  m['id'] as String,
                                  (m['content'] as String?) ?? '',
                                )
                            : null,
                        onDelete: mine
                            ? () => _deleteMessage(m['id'] as String)
                            : null,
                        // Pin: jeder Conversation-Member kann pinnen
                        // (in DMs + Channels). RLS pins_insert_member
                        // setzt is_conversation_member voraus.
                        onPin: () async {
                          final pinned = await MessagesRepository.togglePin(
                            messageId: m['id'] as String,
                            conversationId: widget.conversationId,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surface,
                              content: Text(
                                pinned
                                    ? 'chat.pinned'.tr()
                                    : 'chat.unpinned'.tr(),
                                style: AppTypography.body(
                                    size: 13, color: AppColors.ink),
                              ),
                            ),
                          );
                        },
                            ),
                          ),
                        ],
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
                                memCacheWidth: 80,
                                memCacheHeight: 80,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: MentionsAutocomplete(
                controller: _ctrl,
                conversationId: widget.conversationId,
              ),
            ),
            ChatInputBar(
              controller: _ctrl,
              conversationId: widget.conversationId,
              onSend: _send,
              onVoiceUploaded: _sendVoice,
              // Perf: keine setState bei jedem Keystroke mehr — der
              // Send-Button beobachtet jetzt controller direkt via
              // AnimatedBuilder in ChatInputBar.
              onTextChanged: () {},
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
    required this.conversationId,
    required this.context,
    required this.activeCallId,
    required this.activeStreamRoom,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onStartCall,
    required this.onStartVideoCall,
    required this.onCancelCall,
    required this.onStartStream,
    required this.onEndStream,
    required this.onClearDmHistory,
  });

  final String conversationId;
  final ChatContext? context;
  final String? activeCallId;
  final String? activeStreamRoom;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onStartCall;
  final Future<void> Function() onStartVideoCall;
  final Future<void> Function() onCancelCall;
  final Future<void> Function() onStartStream;
  final Future<void> Function() onEndStream;
  final Future<void> Function() onClearDmHistory;

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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
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
                          ),
                          // R14: 6h-Purge-Countdown in Channel-Header.
                          // Transparenz wann Messages automatisch geloescht werden.
                          if (isChannel) const _PurgeCountdownPill(),
                        ],
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
                if (isDm && widget.activeCallId == null)
                  _ActionIcon(
                    icon: LucideIcons.video,
                    label: 'call.videoAction'.tr(),
                    color: AppColors.bronze,
                    onTap: () async => widget.onStartVideoCall(),
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
                if (isDm)
                  _ActionIcon(
                    icon: LucideIcons.trash2,
                    label: 'chat.clearHistoryAction'.tr(),
                    color: AppColors.mute,
                    onTap: widget.onClearDmHistory,
                  ),
                _ActionIcon(
                  icon: widget.searchOpen
                      ? LucideIcons.x
                      : LucideIcons.search,
                  label: widget.searchOpen ? 'Suche schließen' : 'Suchen',
                  color: widget.searchOpen ? accent : AppColors.mute,
                  onTap: () async => widget.onToggleSearch(),
                ),
                _MuteToggleIcon(conversationId: widget.conversationId),
                if (isDm)
                  _ActionIcon(
                    icon: LucideIcons.eyeOff,
                    label: 'vanish.title'.tr(),
                    color: AppColors.mute,
                    onTap: () async => VanishModeSheet.show(
                      context,
                      conversationId: widget.conversationId,
                    ),
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
      return isOnline ? 'common.online'.tr() : 'common.offline'.tr();
    }
    if (ctx.kind == ChatKind.channel) {
      return ctx.subtitle ?? 'chat.communityChannel'.tr();
    }
    if (ctx.kind == ChatKind.group) return 'chat.groupSubtitle'.tr();
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
                    memCacheWidth: 76,
                    memCacheHeight: 76,
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

class _MuteToggleIcon extends StatefulWidget {
  const _MuteToggleIcon({required this.conversationId});
  final String conversationId;
  @override
  State<_MuteToggleIcon> createState() => _MuteToggleIconState();
}

class _MuteToggleIconState extends State<_MuteToggleIcon> {
  bool? _muted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await ConversationMuteService.instance
        .isMuted(widget.conversationId);
    if (mounted) setState(() => _muted = m);
  }

  Future<void> _toggle() async {
    final next = !(_muted ?? false);
    if (mounted) setState(() => _muted = next);
    await ConversationMuteService.instance
        .setMuted(widget.conversationId, muted: next);
  }

  @override
  Widget build(BuildContext context) {
    final muted = _muted ?? false;
    return _ActionIcon(
      icon: muted ? LucideIcons.bellOff : LucideIcons.bell,
      label: muted ? 'chat.unmute'.tr() : 'chat.mute'.tr(),
      color: muted ? AppColors.bronze : AppColors.mute,
      onTap: () async => _toggle(),
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

// ── Day-Separator (#1) ────────────────────────────────────────────────
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});
  final DateTime date;

  String _label(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'chat.today'.tr();
    if (diff == 1) return 'chat.yesterday'.tr();
    try {
      return DateFormat('EEEE, d. MMMM', context.locale.languageCode)
          .format(date);
    } catch (_) {
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.elevated.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.line,
              width: 0.5,
            ),
          ),
          child: Text(
            _label(context),
            style: AppTypography.label(size: 9, color: AppColors.mute),
          ),
        ),
      ),
    );
  }
}

// ── Unread-Divider (#3) ────────────────────────────────────────────────
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.herzrot.withValues(alpha: 0.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'chat.newMessages'.tr(),
              style: AppTypography.label(
                size: 9,
                color: AppColors.herzrot,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.herzrot.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat-Bubble-Skeleton (#16) ────────────────────────────────────────
class _ChatBubbleSkeleton extends StatelessWidget {
  const _ChatBubbleSkeleton({this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: count,
      itemBuilder: (_, i) {
        final mine = i.isEven;
        final w = 120 + (i * 23) % 130.0;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: w,
            height: 36 + (i * 7) % 20.0,
            decoration: BoxDecoration(
              color: AppColors.elevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4),
                bottomRight: Radius.circular(mine ? 4 : 14),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Empty-State (#17) ─────────────────────────────────────────────────
class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.isSearch,
    required this.searchQuery,
    this.isChannel = false,
    this.channelTitle,
  });
  final bool isSearch;
  final String searchQuery;
  final bool isChannel;
  final String? channelTitle;

  @override
  Widget build(BuildContext context) {
    if (isSearch) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'chat.noSearchResults'.tr(namedArgs: {'q': searchQuery}),
            textAlign: TextAlign.center,
            style: AppTypography.body(
                size: 13, color: AppColors.mute, height: 1.5),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bronze.withValues(alpha: 0.18),
                    AppColors.amber.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: AppColors.bronze.withValues(alpha: 0.3),
                ),
              ),
              child: const Text('🌊', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 16),
            Text(
              isChannel && channelTitle != null
                  ? 'chat.welcomeChannelTitle'.tr(namedArgs: {'name': channelTitle!})
                  : 'chat.emptyTitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isChannel
                  ? 'chat.welcomeChannelBody'.tr()
                  : 'chat.emptySubtitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 12,
                color: AppColors.mute,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── R14: 6h-Purge-Countdown-Pill ──────────────────────────────────────
/// Zeigt im Channel-Header die Zeit bis zum naechsten Auto-Purge
/// (alle 6h um 00/06/12/18 UTC). Updated alle 30s.
class _PurgeCountdownPill extends StatefulWidget {
  const _PurgeCountdownPill();

  @override
  State<_PurgeCountdownPill> createState() => _PurgeCountdownPillState();
}

class _PurgeCountdownPillState extends State<_PurgeCountdownPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _untilNextPurge() {
    final now = DateTime.now().toUtc();
    // Naechster 6h-Slot: 00/06/12/18 UTC
    final nextHour = ((now.hour ~/ 6) + 1) * 6;
    final next = DateTime.utc(now.year, now.month, now.day, nextHour);
    return next.difference(now);
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final d = _untilNextPurge();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.bronze.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.timer,
                size: 9, color: AppColors.bronzeSoft),
            const SizedBox(width: 3),
            Text(
              _format(d),
              style: AppTypography.label(size: 8, color: AppColors.bronzeSoft),
            ),
          ],
        ),
      ),
    );
  }
}
