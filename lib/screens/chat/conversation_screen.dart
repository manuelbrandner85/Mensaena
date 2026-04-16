import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/conversation.dart';
import 'package:mensaena/widgets/chat_bubble.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  RealtimeChannel? _realtimeChannel;
  final List<Message> _realtimeMessages = [];
  Conversation? _conversation;
  List<ConversationMember>? _members;
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _loadConversationMeta();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConversationMeta() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final conv = await chatService.getConversation(widget.conversationId);
      final members = await chatService.getMembers(widget.conversationId);
      if (mounted) {
        setState(() {
          _conversation = conv;
          _members = members;
          _loadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  void _subscribeToMessages() {
    _realtimeChannel = ref.read(chatServiceProvider).subscribeToMessages(
      widget.conversationId,
      (newMessage) {
        // Only add if not sent by current user (we already show it optimistically)
        if (mounted) {
          setState(() {
            // Avoid duplicates
            if (!_realtimeMessages.any((m) => m.id == newMessage.id)) {
              _realtimeMessages.insert(0, newMessage);
            }
          });
          // Auto-scroll to bottom
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      },
    );
  }

  Future<void> _markAsRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(chatServiceProvider)
        .markAsRead(widget.conversationId, userId);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      final sent = await ref.read(chatServiceProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: userId,
            content: content,
          );
      // Add to realtime list to show immediately
      setState(() {
        if (!_realtimeMessages.any((m) => m.id == sent.id)) {
          _realtimeMessages.insert(0, sent);
        }
      });
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _getConversationTitle() {
    if (_conversation?.title != null && _conversation!.title!.isNotEmpty) {
      return _conversation!.title!;
    }

    // For DMs, show the other person's name
    if (_members != null && _conversation?.type == 'direct') {
      final currentUserId = ref.read(currentUserIdProvider);
      final otherMember = _members!.where((m) => m.userId != currentUserId);
      if (otherMember.isNotEmpty) {
        final profile = otherMember.first.profile;
        if (profile != null) {
          return profile['nickname'] as String? ??
              profile['name'] as String? ??
              'Unterhaltung';
        }
      }
    }

    return 'Unterhaltung';
  }

  String? _getOtherAvatarUrl() {
    if (_members != null && _conversation?.type == 'direct') {
      final currentUserId = ref.read(currentUserIdProvider);
      final otherMember = _members!.where((m) => m.userId != currentUserId);
      if (otherMember.isNotEmpty) {
        return otherMember.first.profile?['avatar_url'] as String?;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _loadingMeta
            ? const Text('Unterhaltung')
            : Row(
                children: [
                  if (_conversation?.type == 'direct') ...[
                    AvatarWidget(
                      imageUrl: _getOtherAvatarUrl(),
                      name: _getConversationTitle(),
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getConversationTitle(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_members != null)
                          Text(
                            _conversation?.type == 'direct'
                                ? 'Direktnachricht'
                                : '${_members!.length} Teilnehmer',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConversationInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Locked banner
          if (_conversation?.isLocked == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text(
                    'Diese Unterhaltung ist gesperrt',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const LoadingSkeleton(type: SkeletonType.chat),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (loadedMessages) {
                // Merge loaded messages with realtime messages, avoiding duplicates
                final allMessages = <Message>[];
                final seenIds = <String>{};

                for (final m in _realtimeMessages) {
                  if (seenIds.add(m.id)) allMessages.add(m);
                }
                for (final m in loadedMessages) {
                  if (seenIds.add(m.id)) allMessages.add(m);
                }

                // Sort by createdAt descending (newest first for reverse list)
                allMessages.sort(
                    (a, b) => b.createdAt.compareTo(a.createdAt));

                if (allMessages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppColors.primary50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: AppColors.primary500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Noch keine Nachrichten',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Schreibe die erste Nachricht!',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(
                        messagesProvider(widget.conversationId));
                  },
                  color: AppColors.primary500,
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      final message = allMessages[index];
                      final isMe = message.senderId == currentUserId;

                      // Determine if we should show the avatar
                      // (first message from this sender in a consecutive group)
                      final showAvatar = index == allMessages.length - 1 ||
                          allMessages[index + 1].senderId !=
                              message.senderId;

                      // Show date separator if day changes
                      Widget? dateSeparator;
                      if (index == allMessages.length - 1 ||
                          !_isSameDay(message.createdAt,
                              allMessages[index + 1].createdAt)) {
                        dateSeparator = _buildDateSeparator(
                            message.createdAt);
                      }

                      return Column(
                        children: [
                          if (dateSeparator != null) dateSeparator,
                          ChatBubble(
                            message: message,
                            isMe: isMe,
                            showAvatar: showAvatar,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Message input
          if (_conversation?.isLocked != true)
            Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nachricht schreiben...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.primary500, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary500,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Heute';
    } else if (_isSameDay(
        date, now.subtract(const Duration(days: 1)))) {
      label = 'Gestern';
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showConversationInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unterhaltungs-Info',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (_members != null && _members!.isNotEmpty) ...[
              Text(
                'Teilnehmer (${_members!.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ..._members!.map((member) {
                final name = member.profile?['nickname'] as String? ??
                    member.profile?['name'] as String? ??
                    'Unbekannt';
                final avatarUrl =
                    member.profile?['avatar_url'] as String?;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AvatarWidget(
                    imageUrl: avatarUrl,
                    name: name,
                    size: 36,
                  ),
                  title: Text(name),
                  subtitle: Text(
                    member.role == 'owner' ? 'Ersteller' : 'Mitglied',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
