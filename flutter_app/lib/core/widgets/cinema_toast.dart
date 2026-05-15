import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

enum ToastVariant { success, error, info, warning }

class CinemaToast {
  CinemaToast._();

  static void show(
    BuildContext context, {
    required String message,
    ToastVariant variant = ToastVariant.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.clearSnackBars();

    final ({IconData icon, Color color}) style = switch (variant) {
      ToastVariant.success => (icon: LucideIcons.checkCircle2, color: MnColors.leben),
      ToastVariant.error => (icon: LucideIcons.alertCircle, color: MnColors.herzrot),
      ToastVariant.info => (icon: LucideIcons.info, color: MnColors.teal),
      ToastVariant.warning => (icon: LucideIcons.alertTriangle, color: MnColors.amber),
    };

    scaffold.showSnackBar(
      SnackBar(
        elevation: 8,
        backgroundColor: MnColors.elevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          side: BorderSide(color: style.color.withValues(alpha: 0.20)),
        ),
        duration: duration,
        content: Row(
          children: [
            Icon(style.icon, size: 20, color: style.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: MnTypography.body(color: MnColors.ink)),
            ),
          ],
        ),
        action: (onAction != null && actionLabel != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: MnColors.amber,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
