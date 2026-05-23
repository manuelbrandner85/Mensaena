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
    final ok = await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nachricht konnte nicht gesendet werden.')),
      );
    }
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
                        onReact: (emoji) =>
                            MessagesRepository.toggleReaction(
                          messageId: m['id'] as String,
                          emoji: emoji,
                        ),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.json,
    required this.mine,
    this.showReadReceipt = false,
    this.readByPeer = false,
    this.onReact,
  });
  final Map<String, dynamic> json;
  final bool mine;
  final bool showReadReceipt;
  final bool readByPeer;
  final Future<bool> Function(String emoji)? onReact;

  static const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _openReactionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final emoji in _reactionEmojis)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onReact?.call(emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.elevated,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = json['content'] as String? ?? '';
    final at = DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now();
    return GestureDetector(
      onLongPress:
          onReact == null ? null : () => _openReactionPicker(context),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: mine
                ? AppColors.amber.withValues(alpha: 0.2)
                : AppColors.surface,
            border: Border.all(
              color: mine
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
              Text(
                content,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(at),
                    style:
                        AppTypography.body(size: 10, color: AppColors.mute),
                  ),
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
              if (showReadReceipt && mine && readByPeer) ...[
                const SizedBox(height: 2),
                Text('Gelesen',
                    style: AppTypography.label(
                        size: 8, color: AppColors.tealSoft)),
              ],
            ],
          ),
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
