/// SKILL: mensaena-design (Premium-Motion / Paket D Stolz-Momente)
/// FirstHelpMoment — einmalige Dankes-Sequenz nach der ERSTEN
/// abgeschlossenen Hilfe als Helfer:in.
///
/// Kern der Mission (Nachbarschaftshilfe) → dieser eine Moment darf
/// emotional sein: Higgsfield-Still (onboarding_connect) als Stimmungs-
/// Header, Dank, Teilen-CTA. Konfetti + Haptik via CelebrateBurst
/// (EffectsGate-gegated). Guard via SecureStorage — genau 1x pro Gerät.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/celebrate_burst.dart';
import '../effects/cinematic_backdrop.dart';
import 'glass_card.dart';

const _shownKey = 'mensaena_first_help_thanks_v1';

class FirstHelpMoment {
  const FirstHelpMoment._();

  /// Zeigt die Sequenz genau einmal — beim ersten Abschluss einer Hilfe
  /// als Helfer:in. Storage-Fehler → lieber gar nicht als doppelt.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    const storage = FlutterSecureStorage();
    try {
      if (await storage.read(key: _shownKey) != null) return;
      await storage.write(key: _shownKey, value: '1');
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    CelebrateBurst.fire(context, ref: ref);
    await GlassSheet.show<void>(
      context,
      (ctx) => const _FirstHelpContent(),
    );
  }
}

class _FirstHelpContent extends StatelessWidget {
  const _FirstHelpContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stimmungs-Header: Higgsfield-Still mit Ken-Burns-Drift (full)
          // bzw. statisch (reduced/none) — CinematicBackdrop regelt das.
          const SizedBox(
            height: 150,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(22)),
              child: CinematicBackdrop(
                asset: 'assets/images/onboarding_connect.webp',
                topScrim: 0.15,
                bottomScrim: 0.7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.heartHandshake,
                        size: 22, color: AppColors.herzrotWarm),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'firstHelp.title'.tr(),
                        style: AppTypography.display(
                            size: 20, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'firstHelp.message'.tr(),
                  style: AppTypography.body(
                      size: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.voidColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Share.share('firstHelp.shareText'.tr()),
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: Text('firstHelp.share'.tr(),
                      style: AppTypography.body(
                          size: 14, weight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'firstHelp.close'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft),
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
