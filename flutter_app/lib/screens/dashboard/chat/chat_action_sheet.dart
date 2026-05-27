import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';

/// SKILL: mensaena-features
/// Long-Press Action-Sheet fuer Chat-Bubbles.
/// Zeigt Quick-Reactions + Reply / Edit / Delete / Pin Aktionen.
class ChatActionSheet {
  static const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅'];

  static void open(
    BuildContext context, {
    Future<bool> Function(String emoji)? onReact,
    VoidCallback? onReply,
    VoidCallback? onForward,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onPin,
    VoidCallback? onCopy,
  }) {
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
                  label: 'chat.reply'.tr(),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReply();
                  },
                ),
              if (onForward != null)
                _ActionTile(
                  icon: LucideIcons.share2,
                  label: 'chat.forward'.tr(),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onForward();
                  },
                ),
              if (onCopy != null)
                _ActionTile(
                  icon: LucideIcons.copy,
                  label: 'chat.copy'.tr(),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onCopy();
                  },
                ),
              if (onPin != null)
                _ActionTile(
                  icon: LucideIcons.pin,
                  label: 'chat.pinToggle'.tr(),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onPin();
                  },
                ),
              if (onEdit != null)
                _ActionTile(
                  icon: LucideIcons.edit2,
                  label: 'chat.edit'.tr(),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onEdit();
                  },
                ),
              if (onDelete != null)
                _ActionTile(
                  icon: LucideIcons.trash2,
                  label: 'chat.delete'.tr(),
                  color: AppColors.herzrot,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
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
