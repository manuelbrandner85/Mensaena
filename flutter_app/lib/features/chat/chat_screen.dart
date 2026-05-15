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
import '../../core/widgets/cinema_modal.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/supabase_service.dart';
import 'widgets/message_action_sheet.dart';

final chatMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, convId) {
  return supabase.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', convId)
      .order('created_at');
});

final pinnedMessagesProvider =
    FutureProvider.family<Set<String>, String>((ref, convId) async {
  return db.listPinnedMessageIds(convId);
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return db.isAdmin(user.id);
});

final channelAnnouncementProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, convId) async {
  return db.getActiveAnnouncement(convId);
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
        'sender_id': user.id,
        'content': _msg.text.trim(),
      });
      _msg.clear();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Senden fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  Future<void> _onLongPress(Map<String, dynamic> m, bool isMine) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final isAdmin = ref.read(isAdminProvider).asData?.value ?? false;
    final pinned = ref.read(pinnedMessagesProvider(widget.conversationId))
            .asData
            ?.value ??
        const <String>{};
    final messageId = m['id'] as String?;
    if (messageId == null) return;
    final isPinned = pinned.contains(messageId);

    final action = await MessageActionSheet.show(
      context,
      canEdit: isMine,
      // TODO admin check: aktuell global Admin — pro-Channel Admins folgen.
      canPin: isAdmin,
      isPinned: isPinned,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case MessageAction.edit:
        await _onEdit(messageId, (m['content'] as String?) ?? '');
        break;
      case MessageAction.delete:
        await _onDelete(messageId);
        break;
      case MessageAction.pin:
      case MessageAction.unpin:
        await _onTogglePin(messageId, user.id);
        break;
      case MessageAction.cancel:
        break;
    }
  }

  Future<void> _onEdit(String messageId, String currentContent) async {
    final ctrl = TextEditingController(text: currentContent);
    final saved = await CinemaModal.show<bool>(
      context,
      title: 'Nachricht bearbeiten',
      child: CinemaInput(
        controller: ctrl,
        variant: CinemaInputVariant.multiline,
        autofocus: true,
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Speichern',
          icon: LucideIcons.check,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (saved != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      await db.editMessage(messageId, text);
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Gespeichert.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Bearbeiten fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  Future<void> _onDelete(String messageId) async {
    final confirmed = await CinemaModal.show<bool>(
      context,
      title: 'Loeschen?',
      child: Text(
        'Diese Nachricht wird endgueltig entfernt. Unwiderruflich.',
        style: MnTypography.body(color: MnColors.inkSoft),
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Loeschen',
          icon: LucideIcons.trash2,
          variant: GlowVariant.crisis,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    try {
      await db.deleteMessage(messageId);
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Geloescht.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Loeschen fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  Future<void> _onTogglePin(String messageId, String userId) async {
    try {
      await db.togglePinMessage(messageId, widget.conversationId, userId);
      // ignore: unused_result
      ref.refresh(pinnedMessagesProvider(widget.conversationId));
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Aktualisiert.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Pin fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  Future<void> _onEditAnnouncement(Map<String, dynamic>? existing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ctrl = TextEditingController(
      text: (existing?['content'] as String?) ?? '',
    );
    final saved = await CinemaModal.show<bool>(
      context,
      title: 'Ankuendigung',
      child: CinemaInput(
        controller: ctrl,
        variant: CinemaInputVariant.multiline,
        placeholder: 'Text der Ankuendigung — leer = entfernen.',
        autofocus: true,
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Speichern',
          icon: LucideIcons.check,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (saved != true) return;
    try {
      await db.setChannelAnnouncement(
        widget.conversationId,
        ctrl.text,
        createdBy: user.id,
      );
      // ignore: unused_result
      ref.refresh(channelAnnouncementProvider(widget.conversationId));
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Ankuendigung aktualisiert.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        message: 'Speichern fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final userId = ref.watch(currentUserProvider)?.id;
    final pinned =
        ref.watch(pinnedMessagesProvider(widget.conversationId)).asData?.value ??
            const <String>{};
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
    final announcement =
        ref.watch(channelAnnouncementProvider(widget.conversationId)).asData?.value;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'CHAT'),
      body: SafeArea(
        child: Column(
          children: [
            if (announcement != null || isAdmin)
              _AnnouncementBanner(
                text: (announcement?['content'] as String?) ?? '',
                canEdit: isAdmin,
                onEdit: () => _onEditAnnouncement(announcement),
              ),
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
                      final senderId =
                          (m['sender_id'] ?? m['user_id']) as String?;
                      final isMine = senderId != null && senderId == userId;
                      final id = m['id'] as String?;
                      final isPinned = id != null && pinned.contains(id);
                      return GestureDetector(
                        onLongPress: () => _onLongPress(m, isMine),
                        child: _Bubble(
                          message: m,
                          isMine: isMine,
                          isPinned: isPinned,
                        ),
                      );
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

class _AnnouncementBanner extends StatelessWidget {
  final String text;
  final bool canEdit;
  final VoidCallback onEdit;

  const _AnnouncementBanner({
    required this.text,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    if (!hasText && !canEdit) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MnColors.amber.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: MnColors.lineActive),
        ),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.megaphone, size: 18, color: MnColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasText ? text : 'Noch keine Ankuendigung.',
              style: MnTypography.body(
                color: hasText ? MnColors.inkWarm : MnColors.mute,
                size: 13,
              ),
            ),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 16, color: MnColors.amber),
              onPressed: onEdit,
              tooltip: 'Bearbeiten',
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final bool isPinned;
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final rawContent = (message['content'] as String?) ?? '';
    final isDeleted = message['deleted_at'] != null;
    final isEdited = message['edited_at'] != null && !isDeleted;
    final content = isDeleted ? '[Geloescht]' : rawContent;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          gradient: isMine && !isDeleted
              ? LinearGradient(
                  colors: [
                    MnColors.amber.withValues(alpha: 0.18),
                    MnColors.amber.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isMine && !isDeleted ? null : MnColors.elevated,
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
              const Row(
                children: [
                  CinemaAvatar(size: AvatarSize.xs),
                  SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    content,
                    style: isDeleted
                        ? MnTypography.body(
                            color: MnColors.mute,
                          ).copyWith(fontStyle: FontStyle.italic)
                        : MnTypography.body(color: MnColors.ink),
                  ),
                ),
                if (isPinned && !isDeleted) ...[
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.pin, size: 12, color: MnColors.amber),
                ],
              ],
            ),
            if (isEdited)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '(bearbeitet)',
                  style: MnTypography.caption(color: MnColors.mute),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
