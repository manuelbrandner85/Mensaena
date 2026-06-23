/// SKILL: mensaena-features + mensaena-design
/// Detox-Reminder-Dialog: zeigt sich 1x pro Tag wenn der User
/// den Screen-Time-Threshold erreicht hat.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/bloom.dart';

class DetoxReminderDialog extends StatelessWidget {
  const DetoxReminderDialog({required this.minutes, super.key});

  final int minutes;

  static Future<void> show(BuildContext context, int minutes) {
    // Crash-Schutz (häufigster Null-Check-Absturz lt. error_logs): wird show()
    // mit einem Context ohne Navigator-Ancestor aufgerufen (z. B. der
    // UpdateGate-Context, der über dem Router-Navigator liegt), stürzt
    // showDialog → Navigator.of an einem Null-Check ab. Dann den nicht-
    // kritischen Reminder still überspringen statt zu crashen.
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return Future<void>.value();
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => DetoxReminderDialog(minutes: minutes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Bloom(
              color: AppColors.leben,
              intensity: 0.5,
              radius: 18,
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.leben.withValues(alpha: 0.22),
                  border: Border.all(color: AppColors.leben, width: 2),
                ),
                child: const Icon(LucideIcons.leaf,
                    size: 36, color: AppColors.leben),
              ),
            ),
            const SizedBox(height: 20),
            Text('detox.title'.tr(),
                style: AppTypography.display(size: 20, color: AppColors.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'detox.message'.tr(namedArgs: {'min': '$minutes'}),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // App ganz schliessen → User legt das Telefon weg.
                  SystemNavigator.pop();
                },
                icon: const Icon(LucideIcons.power, size: 16),
                label: Text('detox.pause'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.leben,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('detox.continue'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
