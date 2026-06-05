/// SKILL: mensaena-features (Phase 4 — Livestream-Chat)
/// Halbtransparentes Chat-Overlay am unteren Bildschirmrand mit floating
/// Messages + Reactions + Gift-Buttons. Realtime via Supabase-Subscription.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/mega_models.dart';
import '../../providers/mega_providers.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/chat_word_filter_service.dart';
import '../../services/haptics.dart';

class LivestreamChat extends ConsumerStatefulWidget {
  const LivestreamChat({required this.roomId, super.key});
  final String roomId;

  @override
  ConsumerState<LivestreamChat> createState() => _LivestreamChatState();
}

class _LivestreamChatState extends ConsumerState<LivestreamChat> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _sending) return;
    // Wortfilter auch im öffentlichen Livestream-Chat — hier sehen es
    // potenziell viele Zuschauer gleichzeitig.
    if (!ChatWordFilterService.instance.isClean(txt)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.herzrot,
        content: Text('chat.blockedWord'.tr(),
            style: AppTypography.body(size: 13, color: Colors.white)),
      ));
      return;
    }
    setState(() => _sending = true);
    Haptics.tap();
    await LivestreamMessagesRepository.send(
        roomId: widget.roomId, content: txt);
    if (mounted) {
      setState(() {
        _sending = false;
        _ctrl.clear();
      });
    }
  }

  Future<void> _sendReaction(String emoji) async {
    Haptics.tap();
    await LivestreamMessagesRepository.send(
        roomId: widget.roomId, content: emoji, type: 'reaction');
  }

  bool _sendingGift = false;

  Future<void> _sendGift(String giftType) async {
    // Guard gegen schnelle Mehrfach-Taps (vorher konnte man 5 Gifts in
    // Sekunden senden, jedes mit Karma-Abzug).
    if (_sendingGift) return;
    _sendingGift = true;
    Haptics.confirm();
    // Rückgabe: verbleibendes Karma, oder -1 bei zu wenig Guthaben.
    final remaining = await LivestreamGiftsRepository.send(
        roomId: widget.roomId, giftType: giftType);
    _sendingGift = false;
    if (!mounted) return;
    if (remaining < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('livestream.not_enough_karma'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgsAsync = ref.watch(livestreamMessagesProvider(widget.roomId));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.voidColor.withValues(alpha: 0.6),
            AppColors.voidColor.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating-Messages
          SizedBox(
            height: 220,
            child: msgsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (msgs) {
                if (msgs.isEmpty) return const SizedBox.shrink();
                final visible = msgs.length > 12
                    ? msgs.sublist(msgs.length - 12)
                    : msgs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                        _scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final m = visible[i];
                    if (m.type == 'reaction') {
                      return _ReactionFloat(emoji: m.content);
                    }
                    return _MessageBubble(message: m);
                  },
                );
              },
            ),
          ),

          // Reactions + Gifts Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _ReactBtn(emoji: '❤️', onTap: () => _sendReaction('❤️')),
                _ReactBtn(emoji: '👏', onTap: () => _sendReaction('👏')),
                _ReactBtn(emoji: '🔥', onTap: () => _sendReaction('🔥')),
                _ReactBtn(emoji: '😂', onTap: () => _sendReaction('😂')),
                _ReactBtn(emoji: '😮', onTap: () => _sendReaction('😮')),
                const Spacer(),
                _GiftBtn(
                    icon: '👏',
                    cost: 1,
                    onTap: () => _sendGift('applause')),
                const SizedBox(width: 6),
                _GiftBtn(
                    icon: '🌟',
                    cost: 5,
                    onTap: () => _sendGift('star')),
                const SizedBox(width: 6),
                _GiftBtn(
                    icon: '💎',
                    cost: 20,
                    onTap: () => _sendGift('diamond')),
              ],
            ),
          ),

          // Composer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'livestream.send_message'.tr(),
                      hintStyle:
                          AppTypography.body(size: 13, color: AppColors.mute),
                      filled: true,
                      fillColor: AppColors.surface.withValues(alpha: 0.7),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'common.send'.tr(),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(LucideIcons.send, color: AppColors.bronze),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        AppColors.bronze.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final LivestreamMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.elevated,
            backgroundImage: message.userAvatar != null
                ? CachedNetworkImageProvider(message.userAvatar!)
                : null,
            child: message.userAvatar == null
                ? Text(
                    (message.userName ?? '?').substring(0, 1).toUpperCase(),
                    style: AppTypography.body(
                        size: 10, color: AppColors.bronze))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.userName ?? '...'} ',
                    style: AppTypography.body(
                      size: 11,
                      color: AppColors.bronze,
                      weight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: message.content,
                    style: AppTypography.body(
                        size: 12, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionFloat extends StatefulWidget {
  const _ReactionFloat({required this.emoji});
  final String emoji;

  @override
  State<_ReactionFloat> createState() => _ReactionFloatState();
}

class _ReactionFloatState extends State<_ReactionFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Opacity(
        opacity: (1 - _ac.value).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -_ac.value * 40),
          child: Text(widget.emoji,
              style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

class _ReactBtn extends StatelessWidget {
  const _ReactBtn({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _GiftBtn extends StatelessWidget {
  const _GiftBtn({
    required this.icon,
    required this.cost,
    required this.onTap,
  });
  final String icon;
  final int cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bronze.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.bronze.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 3),
            Text('$cost',
                style: AppTypography.mono(
                    size: 10,
                    color: AppColors.bronze,
                    weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
