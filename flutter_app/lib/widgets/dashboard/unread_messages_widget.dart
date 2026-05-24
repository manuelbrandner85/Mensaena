/// SKILL: mensaena-features
/// UnreadMessagesWidget — Liste ungelesener Direktnachrichten.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class UnreadMessagesWidget extends StatefulWidget {
  const UnreadMessagesWidget({super.key});

  @override
  State<UnreadMessagesWidget> createState() => _UnreadMessagesWidgetState();
}

class _UnreadMessagesWidgetState extends State<UnreadMessagesWidget> {
  late Future<List<_UnreadMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_UnreadMessage>> _load() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final memberships = await sb
          .from('conversation_members')
          .select('conversation_id, last_read_at')
          .eq('user_id', uid);
      final memList =
          (memberships as List).whereType<Map<String, dynamic>>();
      if (memList.isEmpty) return const [];

      final result = <_UnreadMessage>[];
      for (final m in memList) {
        final convId = m['conversation_id'] as String?;
        if (convId == null) continue;
        final lastRead = m['last_read_at'] != null
            ? DateTime.tryParse(m['last_read_at'] as String)
            : null;

        final msgs = await sb
            .from('messages')
            .select('id, content, sender_id, created_at')
            .eq('conversation_id', convId)
            .neq('sender_id', uid)
            .order('created_at', ascending: false)
            .limit(20);
        final msgList = (msgs as List).whereType<Map<String, dynamic>>();
        if (msgList.isEmpty) continue;

        final unread = msgList.where((row) {
          final createdAt =
              DateTime.tryParse(row['created_at'] as String? ?? '');
          if (createdAt == null) return false;
          return lastRead == null || createdAt.isAfter(lastRead);
        }).toList();
        if (unread.isEmpty) continue;

        final newest = unread.first;
        final senderId = newest['sender_id'] as String?;
        String senderName = 'Nachbar:in';
        String? senderAvatar;
        if (senderId != null) {
          try {
            final p = await sb
                .from('profiles')
                .select('name, display_name, avatar_url')
                .eq('id', senderId)
                .maybeSingle();
            if (p != null) {
              senderName = (p['display_name'] as String?) ??
                  (p['name'] as String?) ??
                  senderName;
              senderAvatar = p['avatar_url'] as String?;
            }
          } catch (_) {}
        }
        result.add(_UnreadMessage(
          conversationId: convId,
          senderName: senderName,
          senderAvatar: senderAvatar,
          lastText: (newest['content'] as String?) ?? '',
          timestamp:
              DateTime.tryParse(newest['created_at'] as String? ?? '') ??
                  DateTime.now(),
          unreadCount: unread.length,
        ));
      }
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result.take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'jetzt';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_UnreadMessage>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <_UnreadMessage>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final total = list.fold<int>(0, (s, m) => s + m.unreadCount);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.messageCircle,
                      color: AppColors.herzrotWarm, size: 14),
                  const SizedBox(width: 6),
                  Text('home.unreadMessages'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.herzrotWarm)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$total',
                        style: AppTypography.mono(
                            size: 10, color: AppColors.herzrotWarm)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/dashboard/chat'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 24),
                    ),
                    child: Text('home.allArrow'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.bronze)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final m in list)
                InkWell(
                  onTap: () => context
                      .go('/dashboard/chat?conv=${m.conversationId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.elevated,
                          backgroundImage: (m.senderAvatar != null &&
                                  m.senderAvatar!.isNotEmpty)
                              ? NetworkImage(m.senderAvatar!)
                              : null,
                          child: (m.senderAvatar == null ||
                                  m.senderAvatar!.isEmpty)
                              ? Text(
                                  m.senderName.isNotEmpty
                                      ? m.senderName[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.mono(
                                      size: 12, color: AppColors.bronze),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 13,
                                    color: AppColors.ink,
                                    weight: FontWeight.w600),
                              ),
                              Text(
                                m.lastText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 11, color: AppColors.mute),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_ago(m.timestamp),
                                style: AppTypography.caption()),
                            const SizedBox(height: 2),
                            if (m.unreadCount > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.herzrot,
                                  borderRadius:
                                      BorderRadius.circular(999),
                                ),
                                child: Text('${m.unreadCount}',
                                    style: AppTypography.mono(
                                        size: 9, color: AppColors.ink)),
                              )
                            else
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.herzrot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UnreadMessage {
  const _UnreadMessage({
    required this.conversationId,
    required this.senderName,
    required this.senderAvatar,
    required this.lastText,
    required this.timestamp,
    required this.unreadCount,
  });
  final String conversationId;
  final String senderName;
  final String? senderAvatar;
  final String lastText;
  final DateTime timestamp;
  final int unreadCount;
}
