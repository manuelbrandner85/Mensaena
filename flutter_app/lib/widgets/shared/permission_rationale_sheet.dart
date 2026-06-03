/// SKILL: mensaena-features
/// Pre-Dialog vor dem System-Permission-Dialog. Erklärt nutzwertfokussiert,
/// warum die App diese Berechtigung braucht — damit der User mit hoher
/// Wahrscheinlichkeit auch im System-Dialog auf "Erlauben" tippt.
///
/// Der eigentliche System-Dialog-Text liegt im Android-OS und ist NICHT
/// vom Entwickler veränderbar. Mit diesem Pre-Dialog gleichen wir das aus.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Identifier-Schlüssel: passt 1:1 zum i18n-Namespace
/// `permissions.rationales.items.<key>`.
enum PermissionRationaleKey {
  notification,
  camera,
  microphone,
  photos,
  audio,
  location,
  nearby,
  phone,
}

extension on PermissionRationaleKey {
  String get name => switch (this) {
        PermissionRationaleKey.notification => 'notification',
        PermissionRationaleKey.camera => 'camera',
        PermissionRationaleKey.microphone => 'microphone',
        PermissionRationaleKey.photos => 'photos',
        PermissionRationaleKey.audio => 'audio',
        PermissionRationaleKey.location => 'location',
        PermissionRationaleKey.nearby => 'nearby',
        PermissionRationaleKey.phone => 'phone',
      };

  IconData get icon => switch (this) {
        PermissionRationaleKey.notification => LucideIcons.bell,
        PermissionRationaleKey.camera => LucideIcons.camera,
        PermissionRationaleKey.microphone => LucideIcons.mic,
        PermissionRationaleKey.photos => LucideIcons.image,
        PermissionRationaleKey.audio => LucideIcons.music,
        PermissionRationaleKey.location => LucideIcons.mapPin,
        PermissionRationaleKey.nearby => LucideIcons.bluetooth,
        PermissionRationaleKey.phone => LucideIcons.phoneCall,
      };

  Color get accent => switch (this) {
        PermissionRationaleKey.notification => AppColors.amber,
        PermissionRationaleKey.camera => AppColors.tealSoft,
        PermissionRationaleKey.microphone => AppColors.bronze,
        PermissionRationaleKey.photos => AppColors.lebenSoft,
        PermissionRationaleKey.audio => AppColors.bronzeSoft,
        PermissionRationaleKey.location => AppColors.tealSoft,
        PermissionRationaleKey.nearby => AppColors.tealSoft,
        PermissionRationaleKey.phone => AppColors.amber,
      };
}

/// Zeigt das Rationale-Sheet und gibt zurück, ob der User "Weiter" gedrückt
/// hat (true) — Aufrufer triggert dann den echten Permission-Request.
/// "Später" / Sheet-Dismiss → false (kein System-Dialog).
Future<bool> showPermissionRationale(
  BuildContext context,
  PermissionRationaleKey key,
) async {
  final base = 'permissions.rationales.items.${key.name}';
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag-Handle
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  key.accent.withValues(alpha: 0.34),
                  key.accent.withValues(alpha: 0.08),
                ]),
                boxShadow: [
                  BoxShadow(
                    color: key.accent.withValues(alpha: 0.30),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(key.icon, color: key.accent, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              '$base.title'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 19, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              '$base.body'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 13.5,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: Text(
                  'permissions.rationales.continue'.tr(),
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.voidColor,
                    weight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: key.accent,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'permissions.rationales.later'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.mute),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
