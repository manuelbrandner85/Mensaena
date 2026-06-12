import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../services/dm_call_service.dart';

/// SKILL: mensaena-features
/// Live-Banner — wenn jemand im Channel live ist, koennen
/// alle anderen beitreten. Tap = beitreten als Host/Gast.
class ChatLiveRoomBanner extends StatefulWidget {
  const ChatLiveRoomBanner({
    required this.conversationId,
    required this.channelTitle,
    required this.myUserId,
    super.key,
  });

  final String conversationId;
  final String channelTitle;
  final String? myUserId;

  @override
  State<ChatLiveRoomBanner> createState() => _ChatLiveRoomBannerState();
}

class _ChatLiveRoomBannerState extends State<ChatLiveRoomBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: LiveStreamService.watchActiveRoom(widget.conversationId),
      builder: (context, snap) {
        final room = snap.data;
        if (room == null) return const SizedBox.shrink();
        final roomName = (room['room_name'] as String?) ?? '';
        final topic = (room['topic'] as String?) ?? widget.channelTitle;
        final hostId = room['host_id'] as String?;
        final isHost = hostId != null && hostId == widget.myUserId;
        if (roomName.isEmpty) return const SizedBox.shrink();

        return InkWell(
          onTap: () {
            final title = Uri.encodeComponent(widget.channelTitle);
            final r = Uri.encodeComponent(roomName);
            context.push(
                '/dashboard/live/$r?title=$title&host=${isHost ? '1' : '0'}');
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.herzrot.withValues(alpha: 0.22),
                  AppColors.bronze.withValues(alpha: 0.16),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(
                  color: AppColors.herzrot.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(
                          alpha: 0.5 + _pulse.value * 0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.herzrot.withValues(
                              alpha: 0.6 * _pulse.value),
                          blurRadius: 10 * _pulse.value,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('chat.liveLabel'.tr(),
                    style: AppTypography.label(
                        size: 10, color: AppColors.herzrotWarm)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bronze,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isHost ? 'Zurück' : 'Beitreten',
                    style: AppTypography.body(
                        size: 11,
                        color: AppColors.voidColor,
                        weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// SKILL: mensaena-features
/// Pinned-Messages-Panel — Channel only. 1:1 zu Web PinnedMessages.
class ChatPinnedMessagesPanel extends StatelessWidget {
  const ChatPinnedMessagesPanel({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessagesRepository.watchPinnedMessages(conversationId),
      builder: (context, snap) {
        final pins = snap.data ?? const <Map<String, dynamic>>[];
        if (pins.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.08),
            border:
                Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.pin, size: 14, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${pins.length} angepinnte ${pins.length == 1 ? 'Nachricht' : 'Nachrichten'}',
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.amber,
                      weight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => _showPinsSheet(context, pins),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 28),
                ),
                child: Text('chat.view'.tr(),
                    style: AppTypography.label(
                        size: 10, color: AppColors.amber)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPinsSheet(
      BuildContext context, List<Map<String, dynamic>> pins) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(LucideIcons.pin, color: AppColors.amber),
                const SizedBox(width: 8),
                Text('chat.pinnedMessages'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 14),
            for (final p in pins)
              _PinnedItem(messageId: p['message_id'] as String),
          ],
        ),
      ),
    );
  }
}

class _PinnedItem extends StatelessWidget {
  const _PinnedItem({required this.messageId});
  final String messageId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: MessagesRepository.fetchById(messageId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 40);
        }
        final m = snap.data;
        if (m == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            (m['content'] as String?) ?? '',
            style: AppTypography.body(size: 13, color: AppColors.ink),
          ),
        );
      },
    );
  }
}
