/// SKILL: mensaena-features (F34 QR-Code Profil-Teilen)
/// Zeigt QR-Code des Profil-Links + Share-Button.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class QrShareSheet extends StatelessWidget {
  const QrShareSheet({
    required this.userId,
    required this.displayName,
    super.key,
  });

  final String userId;
  final String displayName;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String displayName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QrShareSheet(userId: userId, displayName: displayName),
    );
  }

  String get _url => 'https://www.mensaena.de/dashboard/profile/$userId';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.qrCode,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('profile.qr_code'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 4),
            Text(displayName,
                style: AppTypography.caption()),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A1A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_url,
                textAlign: TextAlign.center,
                style: AppTypography.caption()),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Share.share('${'profile.share'.tr()}: $_url'),
                icon: const Icon(LucideIcons.share2, size: 16),
                label: Text('profile.share'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
