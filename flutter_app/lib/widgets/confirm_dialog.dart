/// SKILL: mensaena-features
/// Reusable confirm dialog mit AppColors-Style + i18n.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';

class ConfirmDialog {
  const ConfirmDialog._();

  /// Zeigt Confirm-Dialog. Returns true wenn bestaetigt, false sonst.
  /// [danger] = true → roter Confirm-Button (AppColors.herzrot).
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(message,
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel ?? 'common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppColors.herzrot : AppColors.amber,
            ),
            child: Text(confirmLabel ?? 'common.confirm'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
