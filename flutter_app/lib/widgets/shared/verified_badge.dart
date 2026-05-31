import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';

/// SKILL: mensaena-design
/// Verifiziert-Badge — 3 Größen für 3 Kontexte:
///   - inline:   neben dem Namen in PostCard/ChatBubble (16px-Häkchen)
///   - chip:     Profile-Header-Pille mit Label ("Verifiziert")
///   - panel:    Profile-/Settings-Vollblock mit allen 3 Sub-Verifikationen
///
/// Eine Person zählt als "verifiziert", wenn EINE der folgenden Bedingungen
/// erfüllt ist:
///   1. `is_verified` = true (Admin-Verifikation, Bronze-Haken)
///   2. mindestens 2 von {email, phone, community} sind verifiziert
///      → echtes Community-Vertrauen statt nur Admin-Akt.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge.inline({
    required this.profile,
    super.key,
    this.size = 14,
  }) : _variant = _Variant.inline;

  const VerifiedBadge.chip({
    required this.profile,
    super.key,
  })  : size = 12,
        _variant = _Variant.chip;

  final Profile profile;
  final double size;
  final _Variant _variant;

  static bool isVerified(Profile p) {
    if (p.isVerified == true) return true;
    var n = 0;
    if (p.verifiedEmail) n++;
    if (p.verifiedPhone) n++;
    if (p.verifiedCommunity) n++;
    return n >= 2;
  }

  @override
  Widget build(BuildContext context) {
    if (!isVerified(profile)) return const SizedBox.shrink();
    final color = profile.isVerified == true
        ? AppColors.bronze
        : AppColors.tealSoft;
    switch (_variant) {
      case _Variant.inline:
        return Tooltip(
          message: 'verified.badgeTooltip'.tr(),
          child: Icon(LucideIcons.badgeCheck, size: size, color: color),
        );
      case _Variant.chip:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.badgeCheck, size: 12, color: color),
              const SizedBox(width: 4),
              Text('verified.badgeShort'.tr(),
                  style: AppTypography.label(size: 10, color: color)),
            ],
          ),
        );
    }
  }
}

enum _Variant { inline, chip }

/// Voll-Panel für Profile-/Settings-Anzeige aller drei Sub-Verifikationen.
/// Zeigt deutlich an WAS verifiziert ist und WAS noch fehlt — Anreiz für
/// User-eigene Verifikation.
class VerifiedDetailsPanel extends StatelessWidget {
  const VerifiedDetailsPanel({required this.profile, super.key});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _row(LucideIcons.mail, 'verified.email'.tr(), profile.verifiedEmail),
      _row(LucideIcons.phone, 'verified.phone'.tr(), profile.verifiedPhone),
      _row(LucideIcons.users, 'verified.community'.tr(),
          profile.verifiedCommunity),
      if (profile.isVerified == true)
        _row(LucideIcons.shieldCheck, 'verified.admin'.tr(), true,
            color: AppColors.bronze),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.badgeCheck,
                  size: 16, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('verified.panelTitle'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            r,
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, bool ok, {Color? color}) {
    final accent = color ?? (ok ? AppColors.leben : AppColors.mute);
    return Row(
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 13, color: AppColors.ink)),
        ),
        Icon(ok ? LucideIcons.check : LucideIcons.dot,
            size: 14, color: accent),
      ],
    );
  }
}
