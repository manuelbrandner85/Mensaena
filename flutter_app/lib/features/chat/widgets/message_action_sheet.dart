import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cinema_sheet.dart';

/// Auswahl-Aktionen fuer das Long-Press Menue einer Nachricht.
enum MessageAction {
  edit,
  delete,
  pin,
  unpin,
  cancel,
}

/// Long-Press Action-Sheet im Cinema-Style.
/// Zeigt die uebergebenen Optionen — passt sich an eigene Nachrichten
/// (Bearbeiten/Loeschen) und Admin-Rechte (Pin/Loesen) an.
class MessageActionSheet {
  MessageActionSheet._();

  static Future<MessageAction?> show(
    BuildContext context, {
    required bool canEdit,
    required bool canPin,
    required bool isPinned,
  }) {
    return CinemaSheet.show<MessageAction>(
      context,
      initialSize: 0.4,
      snapSizes: const [0.4, 0.6],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text(
                'NACHRICHT',
                style: MnTypography.mono(
                  size: 11,
                  color: MnColors.mute,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            if (canEdit) ...[
              _ActionTile(
                icon: LucideIcons.pencil,
                label: 'Bearbeiten',
                onTap: () => Navigator.of(context).pop(MessageAction.edit),
              ),
              const Divider(color: MnColors.line, height: 1),
            ],
            if (canPin) ...[
              _ActionTile(
                icon: isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                label: isPinned ? 'Loesen' : 'Anpinnen',
                color: MnColors.amber,
                onTap: () => Navigator.of(context).pop(
                  isPinned ? MessageAction.unpin : MessageAction.pin,
                ),
              ),
              const Divider(color: MnColors.line, height: 1),
            ],
            if (canEdit)
              _ActionTile(
                icon: LucideIcons.trash2,
                label: 'Loeschen',
                color: MnColors.herzrot,
                onTap: () => Navigator.of(context).pop(MessageAction.delete),
              ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: LucideIcons.x,
              label: 'Abbrechen',
              color: MnColors.mute,
              onTap: () => Navigator.of(context).pop(MessageAction.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? MnColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 14),
            Text(
              label,
              style: MnTypography.body(color: c, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
