import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/chat_context_service.dart';
import '../../services/dm_call_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

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

  Widget? _buildActionFab() {
    final ctx = _context;
    if (ctx == null) return null;
    if (ctx.kind == ChatKind.dm) {
      // Privat-Anruf-Button (Leben-Green = Phone-Call-Style)
      return FloatingActionButton(
        backgroundColor:
            _activeCallId != null ? AppColors.amber : AppColors.leben,
        foregroundColor: AppColors.voidColor,
        tooltip: _activeCallId != null ? 'Anruf läuft' : 'Anrufen',
        onPressed: _activeCallId != null
            ? () async {
                await DmCallService.cancel(_activeCallId!);
                if (mounted) setState(() => _activeCallId = null);
              }
            : _startCall,
        child: Icon(
          _activeCallId != null
              ? LucideIcons.phoneOff
              : LucideIcons.phoneCall,
        ),
      );
    }
    if (ctx.kind == ChatKind.channel) {
      // Livestream-Button (Bronze = Cinema-Style)
      return FloatingActionButton(
        backgroundColor: _activeStreamRoom != null
            ? AppColors.herzrot
            : AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        tooltip: _activeStreamRoom != null
            ? 'Stream beenden'
            : 'Livestream starten',
        onPressed: _activeStreamRoom != null
            ? () async {
                await LiveStreamService.endChannelStream(_activeStreamRoom!);
                if (mounted) setState(() => _activeStreamRoom = null);
              }
            : _startStream,
        child: Icon(
          _activeStreamRoom != null
              ? LucideIcons.video
              : LucideIcons.radio,
        ),
      );
    }
    return null;
  }

  Future<void> _startCall() async {
    final ctx = _context;
    if (ctx == null || ctx.kind != ChatKind.dm || ctx.partnerId == null) {
      return;
    }
    final result = await DmCallService.start(
      conversationId: widget.conversationId,
      calleeId: ctx.partnerId!,
    );
    if (result == null || !mounted) return;
    setState(() => _activeCallId = result.callId);
    // Navigation in CallScreen — startet LiveKit-Verbindung.
    final peer = Uri.encodeComponent(ctx.title);
    final room = Uri.encodeComponent(result.roomName);
    context.push('/dashboard/call/${result.callId}?room=$room&peer=$peer');
  }

  Future<void> _startStream() async {
    final ctx = _context;
    if (ctx == null || ctx.kind != ChatKind.channel || ctx.slug == null) {
      return;
    }
    final room = await LiveStreamService.startChannelStream(
      channelId: widget.conversationId,
      channelSlug: ctx.slug!,
      topic: 'Live im Kanal ${ctx.title}',
    );
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Livestream konnte nicht gestartet werden.',
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
    if (uid == null || _typingChannel == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingBroadcast) <
        const Duration(milliseconds: 1500)) {
      return;
    }
    _lastTypingBroadcast = now;
    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'from': uid, 'typing': _ctrl.text.isNotEmpty},
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _typingChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    final ok = await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: text,
      replyToId: reply?['id'] as String?,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nachricht konnte nicht gesendet werden.')),
      );
    }
  }

  Future<void> _editMessage(String id, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Nachricht bearbeiten',
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
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Speichern'),
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
        title: Text('Nachricht löschen?',
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text('Die Nachricht wird für alle entfernt.',
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: const Text('Löschen'),
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
      fab: _buildActionFab(),
      body: SafeArea(
        child: Column(
          children: [
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
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return Center(
                      child: Text(
                        'Schreib die erste Nachricht.',
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
                      return _MessageBubble(
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
                    const _TypingDots(),
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
                          Text('Antworten auf',
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.deep,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: AppTypography.body(size: 14, color: AppColors.ink),
                      decoration: const InputDecoration(
                        hintText: 'Nachricht…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(LucideIcons.send, color: AppColors.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.json,
    required this.mine,
    required this.conversationId,
    this.showReadReceipt = false,
    this.readByPeer = false,
    this.onReact,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, dynamic> json;
  final bool mine;
  final String conversationId;
  final bool showReadReceipt;
  final bool readByPeer;
  final Future<bool> Function(String emoji)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅'];
  static final _imgRegex =
      RegExp(r'!\[[^\]]*\]\((https?://[^\s\)]+)\)');

  void _openActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick-Reactions Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final emoji in _reactionEmojis)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          onReact?.call(emoji);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: AppColors.elevated,
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: AppColors.line, height: 24),
              if (onReply != null)
                _ActionTile(
                  icon: LucideIcons.cornerUpLeft,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReply!();
                  },
                ),
              if (onEdit != null)
                _ActionTile(
                  icon: LucideIcons.edit2,
                  label: 'Bearbeiten',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onEdit!();
                  },
                ),
              if (onDelete != null)
                _ActionTile(
                  icon: LucideIcons.trash2,
                  label: 'Löschen',
                  color: AppColors.herzrot,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDelete!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = json['content'] as String? ?? '';
    final at = DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now();
    final editedAt = json['edited_at'] as String?;
    final replyToId = json['reply_to_id'] as String?;
    final deleted = json['deleted_at'] != null;

    // Inline-Image-Match: ![](url) → URL extrahieren, rest = Text
    final imageMatches = _imgRegex.allMatches(content).toList();
    final hasImages = imageMatches.isNotEmpty;
    final textWithoutImages = hasImages
        ? content.replaceAll(_imgRegex, '').trim()
        : content;

    return GestureDetector(
      onLongPress: () => _openActionsSheet(context),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: hasImages
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: deleted
                ? AppColors.elevated.withValues(alpha: 0.5)
                : mine
                    ? AppColors.amber.withValues(alpha: 0.2)
                    : AppColors.surface,
            border: Border.all(
              color: deleted
                  ? AppColors.line
                  : mine
                      ? AppColors.amber.withValues(alpha: 0.4)
                      : AppColors.line,
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply-to-Quote
              if (replyToId != null && !deleted) ...[
                _ReplyQuote(messageId: replyToId),
                const SizedBox(height: 6),
              ],
              // Inline-Images
              if (hasImages && !deleted)
                for (final m in imageMatches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: m.group(1)!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 120,
                          color: AppColors.elevated,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.amber),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                            LucideIcons.imageOff,
                            color: AppColors.mute),
                      ),
                    ),
                  ),
              // Text
              if (deleted)
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
                      : EdgeInsets.zero,
                  child: Text(
                    'Nachricht gelöscht',
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.mute,
                        height: 1.4),
                  ),
                )
              else if (textWithoutImages.isNotEmpty)
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
                      : EdgeInsets.zero,
                  child: Text(
                    textWithoutImages,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              // Reactions-Pills
              if (!deleted)
                _ReactionsPills(
                  messageId: json['id'] as String,
                  conversationId: conversationId,
                  onTap: onReact,
                  padded: hasImages,
                ),
              // Meta (Zeit, Edited, Read-Receipt)
              Padding(
                padding: hasImages
                    ? const EdgeInsets.fromLTRB(8, 0, 8, 4)
                    : EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(at),
                      style: AppTypography.body(
                          size: 10, color: AppColors.mute),
                    ),
                    if (editedAt != null && !deleted) ...[
                      const SizedBox(width: 4),
                      Text('bearbeitet',
                          style: AppTypography.label(
                              size: 8, color: AppColors.mute)),
                    ],
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        readByPeer
                            ? LucideIcons.checkCheck
                            : LucideIcons.check,
                        size: 11,
                        color: readByPeer
                            ? AppColors.tealSoft
                            : AppColors.mute,
                      ),
                    ],
                  ],
                ),
              ),
              if (showReadReceipt && mine && readByPeer) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : EdgeInsets.zero,
                  child: Text('Gelesen',
                      style: AppTypography.label(
                          size: 8, color: AppColors.tealSoft)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reply-Quote (geladen aus messages-Tabelle) ─────────────────────
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.messageId});
  final String messageId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: MessagesRepository.fetchById(messageId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.elevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('lädt…',
                style: AppTypography.body(
                    size: 11, color: AppColors.mute)),
          );
        }
        final row = snap.data;
        if (row == null) return const SizedBox.shrink();
        final c = (row['content'] as String?) ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.elevated.withValues(alpha: 0.6),
            border: const Border(
              left: BorderSide(color: AppColors.bronze, width: 2),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Antwort',
                  style: AppTypography.label(
                      size: 8, color: AppColors.bronzeSoft)),
              Text(
                c.length > 80 ? '${c.substring(0, 80)}…' : c,
                style: AppTypography.body(
                    size: 11, color: AppColors.inkSoft),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reactions-Pills (gruppiert nach Emoji) ─────────────────────────
class _ReactionsPills extends ConsumerWidget {
  const _ReactionsPills({
    required this.messageId,
    required this.conversationId,
    required this.onTap,
    required this.padded,
  });
  final String messageId;
  final String conversationId;
  final Future<bool> Function(String emoji)? onTap;
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessagesRepository.watchReactions(conversationId),
      builder: (context, snap) {
        final all = snap.data ?? const <Map<String, dynamic>>[];
        final mine = SupabaseService.currentUser?.id;
        final reactions = all.where((r) => r['message_id'] == messageId);
        if (reactions.isEmpty) return const SizedBox.shrink();
        final counts = <String, int>{};
        final iReacted = <String, bool>{};
        for (final r in reactions) {
          final e = (r['emoji'] as String?) ?? '?';
          counts[e] = (counts[e] ?? 0) + 1;
          if (r['user_id'] == mine) iReacted[e] = true;
        }
        return Padding(
          padding: padded
              ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
              : const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: counts.entries.map((e) {
              final active = iReacted[e.key] == true;
              return InkWell(
                onTap: () => onTap?.call(e.key),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.bronze.withValues(alpha: 0.22)
                        : AppColors.elevated,
                    border: Border.all(
                      color: active
                          ? AppColors.bronze
                          : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 3),
                      Text('${e.value}',
                          style: AppTypography.mono(
                              size: 10,
                              color: active
                                  ? AppColors.bronze
                                  : AppColors.inkSoft)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 12),
            Text(label,
                style: AppTypography.body(
                    size: 14, color: c, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_ctrl.value + i * 0.18) % 1.0;
            final scale = 0.5 + (1 - (2 * t - 1).abs()) * 0.5;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
