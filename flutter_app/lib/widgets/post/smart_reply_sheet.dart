/// SKILL: mensaena-features + mensaena-design
/// SmartReplySheet: zeigt 3 vorgeschlagene Antworten + frei editierbares
/// Textfeld. Bei Send → DM erstellen + Erstnachricht inserten + zum Chat
/// navigieren.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/haptics.dart';
import '../../services/smart_reply_service.dart';

class SmartReplySheet extends StatefulWidget {
  const SmartReplySheet({
    required this.post,
    required this.postOwnerId,
    super.key,
  });

  final Post post;
  final String postOwnerId;

  static Future<void> show(
    BuildContext context, {
    required Post post,
    required String postOwnerId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SmartReplySheet(post: post, postOwnerId: postOwnerId),
    );
  }

  @override
  State<SmartReplySheet> createState() => _SmartReplySheetState();
}

class _SmartReplySheetState extends State<SmartReplySheet> {
  late final TextEditingController _ctrl;
  late final List<String> _suggestions;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _suggestions = SmartReplyService.suggestionsFor(widget.post);
    _ctrl = TextEditingController(text: _suggestions.first);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openChat({required bool alsoSend}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final convId =
        await ConversationsRepository.getOrCreateDm(widget.postOwnerId);
    if (convId == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (alsoSend && _ctrl.text.trim().isNotEmpty) {
      await MessagesRepository.send(
        conversationId: convId,
        content: _ctrl.text.trim(),
      );
      Haptics.success();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    context.go('/dashboard/messages/$convId');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageCircle,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('smartReply.sheetTitle'.tr(),
                  style: AppTypography.display(
                      size: 17, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text('smartReply.sheetHint'.tr(),
              style: AppTypography.caption()),
          const SizedBox(height: 12),

          // 3 Vorschlags-Chips — Tap fuellt Textfeld
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _suggestions)
                InkWell(
                  onTap: () {
                    Haptics.tap();
                    setState(() => _ctrl.text = s);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.bronze.withValues(alpha: 0.4)),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        s,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            autofocus: true,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'smartReply.placeholder'.tr(),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _openChat(alsoSend: false),
                  icon: const Icon(LucideIcons.messageSquare, size: 14),
                  label: Text('smartReply.openOnly'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _openChat(alsoSend: true),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.voidColor),
                        )
                      : const Icon(LucideIcons.send, size: 14),
                  label: Text('smartReply.send'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
