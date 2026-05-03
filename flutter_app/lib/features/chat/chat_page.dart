import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'chat_repository.dart';
import 'models.dart';

const _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅'];

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  List<ChatChannel> _channels = [];
  ChatChannel? _active;
  bool _loadingChannels = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await ref.read(chatRepositoryProvider).loadChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _active = channels.firstWhere((c) => c.isDefault, orElse: () => channels.first);
        _loadingChannels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingChannels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    if (_loadingChannels) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_channels.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Community Chat')),
        body: const Center(
          child: Text('Keine Channels gefunden', style: TextStyle(color: AppColors.ink400)),
        ),
      );
    }

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _ChannelList(
              channels: _channels,
              active: _active,
              onSelect: (ch) => setState(() => _active = ch),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _active != null
                  ? _MessageThread(key: ValueKey(_active!.id), channel: _active!)
                  : const Center(child: Text('Kanal wählen')),
            ),
          ],
        ),
      );
    }

    // Mobile: show message thread; channel selector via AppBar menu
    return Scaffold(
      appBar: AppBar(
        title: Text('${_active?.emoji ?? ''} ${_active?.name ?? 'Chat'}'),
        actions: [
          PopupMenuButton<ChatChannel>(
            icon: const Icon(Icons.tag),
            tooltip: 'Kanal wechseln',
            onSelected: (ch) => setState(() => _active = ch),
            itemBuilder: (_) => _channels
                .map(
                  (ch) => PopupMenuItem<ChatChannel>(
                    value: ch,
                    child: Text('${ch.emoji} ${ch.name}'),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: _active != null
          ? _MessageThread(key: ValueKey(_active!.id), channel: _active!)
          : const Center(child: Text('Kanal wählen')),
    );
  }
}

// ── Channel list sidebar ──────────────────────────────────────────────────────

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.active,
    required this.onSelect,
  });

  final List<ChatChannel> channels;
  final ChatChannel? active;
  final ValueChanged<ChatChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'CHANNELS',
              style: TextStyle(
                color: AppColors.ink400,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: channels.length,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemBuilder: (_, i) {
                final ch = channels[i];
                final selected = ch.id == active?.id;
                return InkWell(
                  onTap: () => onSelect(ch),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary500.withValues(alpha: 0.12) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(ch.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ch.name,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? AppColors.primary500 : AppColors.ink700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ch.isLocked)
                          const Icon(Icons.lock, size: 12, color: AppColors.ink400),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message thread ────────────────────────────────────────────────────────────

class _MessageThread extends ConsumerStatefulWidget {
  const _MessageThread({super.key, required this.channel});
  final ChatChannel channel;

  @override
  ConsumerState<_MessageThread> createState() => _MessageThreadState();
}

class _MessageThreadState extends ConsumerState<_MessageThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChannelMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  ChannelMessage? _replyTo;
  StreamSubscription<ChannelMessage>? _sub;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = ref.read(supabaseProvider).auth.currentUser?.id;
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    try {
      final msgs = await ref
          .read(chatRepositoryProvider)
          .loadMessages(widget.channel.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _sub = ref
        .read(chatRepositoryProvider)
        .messageStream(widget.channel.conversationId)
        .listen((msg) {
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
      _controller.clear();
    });
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: widget.channel.conversationId,
            content: text,
            replyToId: reply?.id,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showReactionPicker(ChannelMessage msg) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ReactionSheet(
        message: msg,
        myId: _myId ?? '',
        onReact: (emoji) async {
          Navigator.pop(context);
          await ref.read(chatRepositoryProvider).toggleReaction(
                messageId: msg.id,
                emoji: emoji,
              );
        },
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyTo = msg);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Channel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Text(widget.channel.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                widget.channel.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (widget.channel.isLocked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock, size: 14, color: AppColors.ink400),
              ],
              if (widget.channel.description != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.channel.description!,
                    style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Text('Noch keine Nachrichten', style: TextStyle(color: AppColors.ink400)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final prev = i > 0 ? _messages[i - 1] : null;
                        final showDate = prev == null ||
                            !_sameDay(prev.createdAt, msg.createdAt);
                        final groupWithPrev = !showDate &&
                            prev?.senderId == msg.senderId &&
                            msg.createdAt.difference(prev!.createdAt).inMinutes < 5;
                        return Column(
                          children: [
                            if (showDate) _DateDivider(msg.createdAt),
                            _MessageBubble(
                              msg: msg,
                              isMe: msg.senderId == _myId,
                              compact: groupWithPrev,
                              onLongPress: () => _showReactionPicker(msg),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        // Reply indicator
        if (_replyTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.primary500.withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: AppColors.primary500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Antwort an ${_replyTo!.senderProfile?.displayName() ?? 'Unbekannt'}: '
                    '${_replyTo!.content}',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),
        // Input bar
        _InputBar(
          controller: _controller,
          locked: widget.channel.isLocked,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('d. MMMM yyyy', 'de').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.compact,
    required this.onLongPress,
  });

  final ChannelMessage msg;
  final bool isMe;
  final bool compact;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final name = msg.senderProfile?.displayName() ?? 'Unbekannt';
    final time = DateFormat('HH:mm').format(msg.createdAt);
    final avatar = msg.senderProfile?.avatarUrl;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: compact ? 2 : 10,
          bottom: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (only for first in group)
            SizedBox(
              width: 36,
              child: compact
                  ? null
                  : CircleAvatar(
                      radius: 18,
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                      child: avatar == null
                          ? Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                          : null,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isMe ? AppColors.primary500 : AppColors.ink700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(time, style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
                      ],
                    ),
                  // Reply preview
                  if (msg.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.ink400.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(
                          left: BorderSide(color: AppColors.primary500, width: 2),
                        ),
                      ),
                      child: Text(
                        '${msg.replyTo!.senderName ?? ''}: ${msg.replyTo!.content}',
                        style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Content
                  if (msg.isDeleted)
                    const Text(
                      'Nachricht gelöscht',
                      style: TextStyle(
                        color: AppColors.ink400,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    )
                  else
                    Text(msg.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                  // Reactions
                  if (msg.reactions.isNotEmpty) _ReactionRow(reactions: msg.reactions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.reactions});
  final List<MessageReaction> reactions;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, int>{};
    for (final r in reactions) {
      grouped[r.emoji] = (grouped[r.emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: grouped.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary500.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary500.withValues(alpha: 0.25)),
          ),
          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }
}

class _ReactionSheet extends StatelessWidget {
  const _ReactionSheet({
    required this.message,
    required this.myId,
    required this.onReact,
    required this.onReply,
  });

  final ChannelMessage message;
  final String myId;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _quickEmojis.map((emoji) {
                final already = message.reactions.any(
                  (r) => r.userId == myId && r.emoji == emoji,
                );
                return GestureDetector(
                  onTap: () => onReact(emoji),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: already
                          ? AppColors.primary500.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Antworten'),
              onTap: onReply,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.locked,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool locked;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !locked,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: locked ? 'Kanal gesperrt' : 'Nachricht schreiben…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          sending
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.primary500,
                  onPressed: locked ? null : onSend,
                ),
        ],
      ),
    );
  }
}
