import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import '../calls/models.dart' as calls;
import '../calls/outgoing_call_page.dart';
import 'messages_repository.dart';
import 'models.dart';
import 'voice_recorder_button.dart';

final _voiceRegex = RegExp(r'^\[Sprachnachricht\s+(\d+)s\]\((.+)\)$');

/// Thread-View einer Conversation – Pendant zur "Detail-Spalte" in
/// ChatView.tsx (wenn ?conv=… gesetzt ist).
/// Lädt Messages initial, hängt Realtime-INSERTs an, sendet via Repo.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  bool _initialLoaded = false;
  bool _sending = false;
  bool _uploadingImage = false;
  Profile? _other;

  // Edit-Mode
  String? _editingMessageId;

  // Reply-Mode: ID + preview-text der Nachricht, auf die geantwortet wird.
  String? _replyToId;
  String? _replyToPreview;
  String? _replyToSenderName;

  // Reactions: messageId -> List of {emoji, userId}.
  Map<String, List<Map<String, dynamic>>> _reactions = const {};
  StreamSubscription<MessageReactionEvent>? _reactionsSub;

  // Mentions-State: aktiver @query + Match-Liste + Caret-Position des @.
  String? _mentionQuery;
  int _mentionStart = -1;
  List<Map<String, dynamic>> _mentionMatches = const [];
  Timer? _mentionDebounce;

  // Read-Receipts: zeitstempel des letzten "gelesen" vom Gegenüber.
  DateTime? _otherLastReadAt;

  // Typing-Indicator
  RealtimeChannel? _typingChannel;
  Timer? _typingDebounce;
  Timer? _typingClearTimer;
  String? _otherTypingName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _setupTypingChannel();
    _input.addListener(_detectMention);
  }

  /// Beobachtet das Composer-Feld: wenn der Cursor unmittelbar hinter einem
  /// `@<wort>`-Pattern steht, lädt asynchron 5 passende Profile und zeigt
  /// die Autocomplete-Dropdown.
  void _detectMention() {
    final sel = _input.selection;
    final text = _input.text;
    if (!sel.isValid || sel.baseOffset != sel.extentOffset) {
      _clearMention();
      return;
    }
    final cursor = sel.baseOffset.clamp(0, text.length);
    // Suche rückwärts vom Cursor nach @, abbrechen bei Whitespace/Newline.
    var atPos = -1;
    for (var i = cursor - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == '@') {
        atPos = i;
        break;
      }
      if (ch == ' ' || ch == '\n' || ch == '\t') break;
    }
    if (atPos < 0) {
      _clearMention();
      return;
    }
    // @ darf am Wortanfang stehen (Beginn oder nach Whitespace).
    if (atPos > 0) {
      final before = text[atPos - 1];
      if (before != ' ' && before != '\n') {
        _clearMention();
        return;
      }
    }
    final query = text.substring(atPos + 1, cursor);
    if (query.length > 30) {
      _clearMention();
      return;
    }
    setState(() {
      _mentionQuery = query;
      _mentionStart = atPos;
    });
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 200), () {
      _searchMentionCandidates(query);
    });
  }

  void _clearMention() {
    if (_mentionQuery == null && _mentionMatches.isEmpty) return;
    setState(() {
      _mentionQuery = null;
      _mentionStart = -1;
      _mentionMatches = const [];
    });
  }

  Future<void> _searchMentionCandidates(String q) async {
    try {
      final db = ref.read(supabaseProvider);
      final safe = q.replaceAll(RegExp(r'[%_\\,()]'), ' ').trim();
      // Bei leerem Query: zeige Channel-Mitglieder (vereinfacht: globale
      // Profile-Suche limitiert auf 5).
      final rows = safe.isEmpty
          ? await db
              .from('profiles')
              .select('id, name, avatar_url')
              .limit(5)
          : await db
              .from('profiles')
              .select('id, name, avatar_url')
              .ilike('name', '%$safe%')
              .limit(5);
      if (!mounted || _mentionQuery != q) return;
      setState(() => _mentionMatches = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  void _insertMention(Map<String, dynamic> profile) {
    final name = (profile['name'] as String?) ?? '';
    if (_mentionStart < 0 || _mentionQuery == null) return;
    final endOfQuery = _mentionStart + 1 + _mentionQuery!.length;
    final before = _input.text.substring(0, _mentionStart);
    final after = _input.text.substring(endOfQuery);
    final replacement = '@$name ';
    _input.text = '$before$replacement$after';
    final newCursor = before.length + replacement.length;
    _input.selection = TextSelection.collapsed(offset: newCursor);
    _clearMention();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(messagesRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final initial = await repo.listMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(initial);
      _initialLoaded = true;
    });
    _scrollToBottom();
    if (user != null) {
      await repo.markAsRead(conversationId: widget.conversationId, userId: user.id);
      _loadOtherProfile(user.id);
      _refreshOtherLastReadAt(user.id);
    }
    // Reactions initial laden + auf Realtime subscribed.
    _loadReactions(initial.map((m) => m.id).toList());
    _subscribeReactions();
  }

  Future<void> _loadReactions(List<String> messageIds) async {
    try {
      final map = await ref
          .read(messagesRepositoryProvider)
          .reactionsFor(messageIds);
      if (!mounted) return;
      setState(() => _reactions = map);
    } catch (_) {}
  }

  void _subscribeReactions() {
    _reactionsSub = ref
        .read(messagesRepositoryProvider)
        .reactionsStream(widget.conversationId)
        .listen((event) {
      if (!mounted) return;
      setState(() {
        final list =
            List<Map<String, dynamic>>.from(_reactions[event.messageId] ?? []);
        if (event.isInsert) {
          // Doppelte vermeiden.
          if (!list.any(
            (r) =>
                r['user_id'] == event.userId && r['emoji'] == event.emoji,
          )) {
            list.add({'emoji': event.emoji, 'user_id': event.userId});
          }
        } else {
          list.removeWhere(
            (r) => r['user_id'] == event.userId && r['emoji'] == event.emoji,
          );
        }
        _reactions = {..._reactions, event.messageId: list};
      });
    });
  }

  Future<void> _toggleReaction(Message m, String emoji) async {
    try {
      await ref.read(messagesRepositoryProvider).toggleReaction(
            messageId: m.id,
            emoji: emoji,
          );
      // Realtime-Event aktualisiert State; optimistisch nicht nötig.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaktion fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _showReactionPicker(Message m) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              for (final e in const ['👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '🔥'])
                IconButton(
                  iconSize: 32,
                  onPressed: () => Navigator.of(ctx).pop(e),
                  icon: Text(e, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji != null) {
      await _toggleReaction(m, emoji);
    }
  }

  Future<void> _refreshOtherLastReadAt(String myId) async {
    try {
      final stamps = await ref
          .read(messagesRepositoryProvider)
          .otherMembersLastReadAt(
            conversationId: widget.conversationId,
            myUserId: myId,
          );
      DateTime? max;
      for (final s in stamps) {
        if (s == null) continue;
        if (max == null || s.isAfter(max)) max = s;
      }
      if (!mounted) return;
      setState(() => _otherLastReadAt = max);
    } catch (_) {}
  }

  Future<void> _loadOtherProfile(String myId) async {
    final rows = await sb
        .from('conversation_members')
        .select('user_id, profiles!inner(id, name, avatar_url)')
        .eq('conversation_id', widget.conversationId)
        .neq('user_id', myId)
        .limit(1);
    if (!mounted || rows.isEmpty) return;
    final p = rows.first['profiles'];
    if (p is Map<String, dynamic>) {
      setState(() => _other = Profile.fromJson(p));
    }
  }

  void _startCall(calls.DmCallType type) {
    final other = _other;
    if (other == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => OutgoingCallPage(
          conversationId: widget.conversationId,
          callee: other,
          callType: type,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(messagesRepositoryProvider);
      // Edit-Mode? Dann update statt insert.
      final editingId = _editingMessageId;
      if (editingId != null) {
        await repo.editMessage(messageId: editingId, newContent: text);
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == editingId);
          if (idx >= 0) {
            _messages[idx] = _messages[idx].copyWith(
              content: text,
              editedAt: DateTime.now(),
            );
          }
          _editingMessageId = null;
        });
        _input.clear();
        return;
      }
      final msg = await repo.sendMessage(
        conversationId: widget.conversationId,
        senderId: user.id,
        content: text,
        replyToId: _replyToId,
      );
      _input.clear();
      // Optimistic – auch Realtime liefert es zurück; doppelt fügen wir nicht ein.
      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
      }
      // Reply-Mode beenden nach erfolgreichem Send.
      if (_replyToId != null) {
        setState(() {
          _replyToId = null;
          _replyToPreview = null;
          _replyToSenderName = null;
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Senden fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Bild aus Galerie wählen, in `chat-images` Bucket hochladen, als
  /// Markdown-Bildlink senden (`![Bild](url)`). Web rendert dasselbe Format.
  Future<void> _attachImage() async {
    if (_uploadingImage) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingImage = true);
    try {
      final msg = await ref.read(messagesRepositoryProvider).sendImageMessage(
            conversationId: widget.conversationId,
            senderId: user.id,
            file: File(picked.path),
          );
      if (!_messages.any((m) => m.id == msg.id) && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bild senden fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _startEdit(Message m) {
    setState(() {
      _editingMessageId = m.id;
      _input.text = m.content;
      _input.selection = TextSelection.fromPosition(
        TextPosition(offset: _input.text.length),
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _input.clear();
    });
  }

  void _startReply(Message m) {
    setState(() {
      _replyToId = m.id;
      // Bei Image-Bubble „📷 Bild" als Preview, sonst Content gekürzt.
      _replyToPreview =
          m.isImageMessage ? '📷 Bild' : m.content.replaceAll('\n', ' ');
      _replyToSenderName = m.senderProfile?.displayName();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToPreview = null;
      _replyToSenderName = null;
    });
  }

  Future<void> _deleteMessage(Message m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nachricht löschen?'),
        content: const Text(
          'Die Nachricht wird für alle Teilnehmer ausgeblendet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergency500),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(messagesRepositoryProvider).softDeleteMessage(m.id);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((x) => x.id == m.id);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(deletedAt: DateTime.now());
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  void _showMessageActions(Message m, {required bool isOwn}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.isDeleted)
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Reagieren'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showReactionPicker(m);
                },
              ),
            if (!m.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Antworten'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startReply(m);
                },
              ),
            if (!m.isDeleted && !m.isImageMessage)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopieren'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Clipboard.setData(ClipboardData(text: m.content));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('In Zwischenablage kopiert')),
                  );
                },
              ),
            if (isOwn && !m.isDeleted && !m.isImageMessage)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Bearbeiten'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startEdit(m);
                },
              ),
            if (isOwn && !m.isDeleted)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.emergency500,
                ),
                title: const Text(
                  'Löschen',
                  style: TextStyle(color: AppColors.emergency500),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Typing-Indicator ────────────────────────────────────────────────────
  void _setupTypingChannel() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(messagesRepositoryProvider);
    _typingChannel = repo.typingChannel(widget.conversationId)
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final typingUserId = payload['userId']?.toString();
          if (typingUserId == null || typingUserId == user.id) return;
          final name = payload['name']?.toString() ?? 'Jemand';
          if (!mounted) return;
          setState(() => _otherTypingName = name);
          _typingClearTimer?.cancel();
          _typingClearTimer = Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _otherTypingName = null);
          });
        },
      )
      ..subscribe();
  }

  /// Wird in `_Composer` aus dem onChanged-Callback aufgerufen.
  /// Debounced: max. 1× pro Sekunde wird ein typing-Event gesendet.
  void _onUserTyping() {
    final channel = _typingChannel;
    final user = ref.read(currentUserProvider);
    if (channel == null || user == null) return;
    if (_typingDebounce?.isActive ?? false) return;
    _typingDebounce = Timer(const Duration(seconds: 1), () {});
    ref.read(messagesRepositoryProvider).broadcastTyping(
          channel: channel,
          userId: user.id,
          name: user.userMetadata?['name']?.toString() ?? 'Jemand',
        );
  }

  @override
  void dispose() {
    _input.removeListener(_detectMention);
    _input.dispose();
    _scroll.dispose();
    _typingDebounce?.cancel();
    _typingClearTimer?.cancel();
    _mentionDebounce?.cancel();
    if (_typingChannel != null) sb.removeChannel(_typingChannel!);
    _reactionsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Realtime-Subscription auf neue Messages
    ref.listen<AsyncValue<Message>>(
      conversationStreamProvider(widget.conversationId),
      (_, next) {
        next.whenData((m) {
          if (_messages.any((existing) => existing.id == m.id)) return;
          setState(() => _messages.add(m));
          _scrollToBottom();
          // Beim Empfang fremder Nachricht: re-fetch read-stamps demnächst.
          final user = ref.read(currentUserProvider);
          if (user != null && m.senderId != user.id) {
            // Wir haben gerade eine fremde Message bekommen.
            ref.read(messagesRepositoryProvider).markAsRead(
                  conversationId: widget.conversationId,
                  userId: user.id,
                );
          }
        });
      },
    );

    // Realtime-Subscription auf UPDATE-Events (Edit, Soft-Delete vom Web).
    ref.listen<AsyncValue<Message>>(
      conversationUpdateStreamProvider(widget.conversationId),
      (_, next) {
        next.whenData((m) {
          final idx = _messages.indexWhere((existing) => existing.id == m.id);
          if (idx < 0) return;
          setState(() => _messages[idx] = m);
        });
      },
    );

    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_other?.displayName() ?? 'Gespräch'),
        actions: _other == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.call),
                  tooltip: 'Sprachanruf',
                  onPressed: () => _startCall(calls.DmCallType.audio),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam),
                  tooltip: 'Videoanruf',
                  onPressed: () => _startCall(calls.DmCallType.video),
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_initialLoaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isOwn = user != null && m.senderId == user.id;
                      final showTime = _shouldShowTimeBefore(i);
                      final readByOther = isOwn &&
                          _otherLastReadAt != null &&
                          !m.createdAt.isAfter(_otherLastReadAt!);
                      return Column(
                        crossAxisAlignment: isOwn
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  _dayLabel(m.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.stone500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onLongPress: m.isDeleted
                                ? null
                                : () => _showMessageActions(m, isOwn: isOwn),
                            child: _Bubble(
                              message: m,
                              isOwn: isOwn,
                              readByOther: readByOther,
                            ),
                          ),
                          if (!m.isDeleted)
                            _ReactionsRow(
                              messageId: m.id,
                              reactions: _reactions[m.id] ?? const [],
                              myUserId: user?.id,
                              isOwn: isOwn,
                              onToggle: (emoji) => _toggleReaction(m, emoji),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (_otherTypingName != null)
            _TypingIndicator(name: _otherTypingName!),
          if (_editingMessageId != null)
            _EditingBanner(onCancel: _cancelEdit),
          if (_replyToId != null)
            _ReplyingBanner(
              senderName: _replyToSenderName,
              preview: _replyToPreview,
              onCancel: _cancelReply,
            ),
          if (_mentionQuery != null && _mentionMatches.isNotEmpty)
            _MentionDropdown(
              candidates: _mentionMatches,
              onSelect: _insertMention,
            ),
          _Composer(
            controller: _input,
            sending: _sending,
            uploading: _uploadingImage,
            onSend: _send,
            onAttachImage: _attachImage,
            onTextChanged: _onUserTyping,
            isEditing: _editingMessageId != null,
            conversationId: widget.conversationId,
            userId: user?.id,
          ),
        ],
      ),
    );
  }

  bool _shouldShowTimeBefore(int i) {
    if (i == 0) return true;
    final prev = _messages[i - 1].createdAt;
    final cur = _messages[i].createdAt;
    return prev.year != cur.year || prev.month != cur.month || prev.day != cur.day;
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
    if (isToday) return 'Heute';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day;
    if (isYesterday) return 'Gestern';
    return DateFormat('EEEE, d. MMMM', 'de').format(t);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isOwn,
    required this.readByOther,
  });
  final Message message;
  final bool isOwn;
  final bool readByOther;

  @override
  Widget build(BuildContext context) {
    final bg = isOwn ? AppColors.primary500 : AppColors.paper;
    final fg = isOwn ? Colors.white : AppColors.ink800;
    final mutedFg =
        isOwn ? Colors.white.withValues(alpha: 0.75) : AppColors.stone400;
    final isImage = message.isImageMessage && !message.isDeleted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            padding: isImage
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOwn ? 16 : 4),
                bottomRight: Radius.circular(isOwn ? 4 : 16),
              ),
              border: isOwn ? null : Border.all(color: AppColors.stone200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isReply && message.replyToContent != null) ...[
                  _QuoteBlock(
                    senderName: message.replyToSenderName,
                    preview: message.replyToContent!,
                    isOwn: isOwn,
                  ),
                  const SizedBox(height: 6),
                ],
                _bubbleContent(fg),
                const SizedBox(height: 4),
                Padding(
                  padding: isImage
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                      : EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(fontSize: 10, color: mutedFg),
                      ),
                      if (message.isEdited && !message.isDeleted) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· bearbeitet',
                          style: TextStyle(
                            fontSize: 10,
                            color: mutedFg,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        Icon(
                          readByOther ? Icons.done_all : Icons.done,
                          size: 12,
                          color: readByOther ? Colors.lightBlueAccent : mutedFg,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubbleContent(Color fg) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Text(
          'Nachricht gelöscht',
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final voiceMatch = _voiceRegex.firstMatch(message.content.trim());
    if (voiceMatch != null) {
      return _VoiceMessagePlayer(
        url: voiceMatch.group(2)!,
        durationSeconds: int.tryParse(voiceMatch.group(1) ?? '') ?? 0,
        isOwn: isOwn,
      );
    }
    final imgUrl = message.imageUrl;
    if (imgUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(
            height: 180,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 100,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image, color: fg),
          ),
        ),
      );
    }
    return Text(
      message.content,
      style: TextStyle(color: fg, fontSize: 14),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stone200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8),
              Text(
                '$name schreibt …',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.stone500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  const _EditingBanner({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary500.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.primary500,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nachricht bearbeiten',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.primary500,
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline-Audio-Player für Sprachnachrichten in Chat-Bubbles.
/// Lazy-Load: lädt erst beim ersten Play, spart Bandbreite in langen Listen.
class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({
    required this.url,
    required this.durationSeconds,
    required this.isOwn,
  });
  final String url;
  final int durationSeconds;
  final bool isOwn;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final _player = FlutterSoundPlayer();
  bool _opened = false;
  bool _isPlaying = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<PlaybackDisposition>? _sub;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.durationSeconds);
  }

  Future<bool> _ensureOpen() async {
    if (_opened) return true;
    try {
      await _player.openPlayer();
      await _player.setSubscriptionDuration(const Duration(milliseconds: 100));
      _sub = _player.onProgress?.listen((d) {
        if (!mounted) return;
        setState(() {
          _position = d.position;
          if (d.duration.inMilliseconds > 0) _total = d.duration;
        });
      });
      _opened = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_opened) {
      _player.closePlayer();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_failed) return;
    try {
      if (!await _ensureOpen()) {
        if (!mounted) return;
        setState(() => _failed = true);
        return;
      }
      if (_isPlaying) {
        await _player.pausePlayer();
        if (!mounted) return;
        setState(() => _isPlaying = false);
        return;
      }
      if (_player.isPaused) {
        await _player.resumePlayer();
      } else {
        await _player.startPlayer(
          fromURI: widget.url,
          codec: Codec.aacMP4,
          whenFinished: () {
            if (!mounted) return;
            setState(() {
              _position = Duration.zero;
              _isPlaying = false;
            });
          },
        );
      }
      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isOwn ? Colors.white : AppColors.ink800;
    final accent = widget.isOwn ? Colors.white : AppColors.primary500;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              _failed
                  ? Icons.error_outline
                  : _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
              color: accent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: widget.isOwn
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.stone200,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _format(_isPlaying || progress > 0 ? _position : _total),
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.uploading,
    required this.onAttachImage,
    required this.onTextChanged,
    required this.isEditing,
    required this.conversationId,
    required this.userId,
  });

  final TextEditingController controller;
  final String conversationId;
  final String? userId;
  final VoidCallback onSend;
  final VoidCallback onAttachImage;
  final VoidCallback onTextChanged;
  final bool sending;
  final bool uploading;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final canSend = !sending && !uploading;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.stone200)),
        ),
        child: Row(
          children: [
            // Bild-Anhang nicht im Edit-Mode (passt nicht zum Edit-Pattern).
            if (!isEditing)
              IconButton(
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                color: AppColors.primary500,
                tooltip: 'Bild senden',
                onPressed: uploading ? null : onAttachImage,
              ),
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onChanged: (_) => onTextChanged(),
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isEditing
                      ? 'Nachricht bearbeiten…'
                      : 'Nachricht schreiben…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            if (!isEditing && userId != null)
              VoiceRecorderButton(
                conversationId: conversationId,
                userId: userId!,
              ),
            const SizedBox(width: 4),
            Material(
              color: AppColors.primary500,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? onSend : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    sending
                        ? Icons.hourglass_empty
                        : (isEditing ? Icons.check : Icons.send),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quote-Block in Bubble — zeigt zitierte Original-Message darüber.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({
    required this.senderName,
    required this.preview,
    required this.isOwn,
  });
  final String? senderName;
  final String preview;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final fg = isOwn ? Colors.white : AppColors.ink800;
    final bg = isOwn
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.primary500.withValues(alpha: 0.08);
    final accent = isOwn ? Colors.white : AppColors.primary500;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName ?? 'Antwort',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: fg.withValues(alpha: 0.85),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner über dem Composer im Reply-Mode — zeigt auf welche Message
/// gerade geantwortet wird, mit Cancel-Button.
class _ReplyingBanner extends StatelessWidget {
  const _ReplyingBanner({
    required this.senderName,
    required this.preview,
    required this.onCancel,
  });
  final String? senderName;
  final String? preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary500.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.reply_outlined,
                size: 16, color: AppColors.primary500,),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antwort an ${senderName ?? 'Nachricht'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary500,
                    ),
                  ),
                  if (preview != null && preview!.isNotEmpty)
                    Text(
                      preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink700,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.primary500,
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pillen-Row unter einer Bubble: zeigt aggregierte Reactions mit Counter.
/// Tap auf eine Pille toggelt die eigene Reaction. Tap auf das + öffnet
/// keinen Picker hier (Long-Press macht das).
class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.messageId,
    required this.reactions,
    required this.myUserId,
    required this.isOwn,
    required this.onToggle,
  });

  final String messageId;
  final List<Map<String, dynamic>> reactions;
  final String? myUserId;
  final bool isOwn;
  final void Function(String emoji) onToggle;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    // Gruppiere nach Emoji.
    final byEmoji = <String, List<String>>{};
    for (final r in reactions) {
      final e = r['emoji'] as String?;
      final u = r['user_id'] as String?;
      if (e == null || u == null) continue;
      byEmoji.putIfAbsent(e, () => []).add(u);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: isOwn ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: byEmoji.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final mine = myUserId != null && users.contains(myUserId);
          return Material(
            borderRadius: BorderRadius.circular(20),
            color: mine
                ? AppColors.primary500.withValues(alpha: 0.15)
                : AppColors.stone100,
            child: InkWell(
              onTap: () => onToggle(emoji),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    if (users.length > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${users.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mine
                              ? AppColors.primary500
                              : AppColors.ink600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Autocomplete-Dropdown über dem Composer, sobald der User `@<wort>` tippt.
/// Liefert max 5 Profile-Einträge (Avatar + Name); Tap wählt aus.
class _MentionDropdown extends StatelessWidget {
  const _MentionDropdown({
    required this.candidates,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> candidates;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          top: BorderSide(color: AppColors.stone200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: candidates.length,
        itemBuilder: (_, i) {
          final p = candidates[i];
          final name = (p['name'] as String?) ?? 'Unbekannt';
          final avatar = p['avatar_url'] as String?;
          return InkWell(
            onTap: () => onSelect(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.stone200,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink400,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@$name',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
