import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/supabase_service.dart';

final chatMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, convId) {
  return supabase.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', convId)
      .order('created_at');
});

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msg = TextEditingController();

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _msg.text.trim().isEmpty) return;
    try {
      await supabase.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'user_id': user.id,
        'content': _msg.text.trim(),
      });
      _msg.clear();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final userId = ref.watch(currentUserProvider)?.id;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'CHAT'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
                error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return Center(
                      child: Text(
                        'Schreib die erste Nachricht.',
                        style: MnTypography.body(color: MnColors.mute),
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[msgs.length - 1 - i];
                      final isMine = m['user_id'] == userId;
                      return _Bubble(message: m, isMine: isMine);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: MnColors.surface,
                border: Border(top: BorderSide(color: MnColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CinemaInput(
                      controller: _msg,
                      placeholder: 'Nachricht...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlowButton(
                    label: '',
                    icon: LucideIcons.send,
                    compact: true,
                    onPressed: _send,
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

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  const _Bubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final content = (message['content'] as String?) ?? '';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          gradient: isMine
              ? LinearGradient(
                  colors: [
                    MnColors.amber.withValues(alpha: 0.18),
                    MnColors.amber.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isMine ? null : MnColors.elevated,
          border: Border(
            left: BorderSide(
              color: isMine ? MnColors.amber : MnColors.tealDeep,
              width: 3,
            ),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMine ? 16 : 4),
            topRight: Radius.circular(isMine ? 4 : 16),
            bottomLeft: const Radius.circular(MnDimensions.radiusCard),
            bottomRight: const Radius.circular(MnDimensions.radiusCard),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Row(
                children: const [
                  CinemaAvatar(size: AvatarSize.xs),
                  SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(content, style: MnTypography.body(color: MnColors.ink)),
          ],
        ),
      ),
    );
  }
}
