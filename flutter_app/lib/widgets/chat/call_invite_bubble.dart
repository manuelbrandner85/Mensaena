/// SKILL: mensaena-features (Phase 3 F13)
/// Chat-Bubble die einen `[CALL_INVITE:<roomName>]`-Marker als
/// "Group-Call läuft — Beitreten"-Karte rendert.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class CallInviteBubble extends StatelessWidget {
  const CallInviteBubble({required this.roomName, super.key});
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dashboard/group-call/$roomName'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.bronze.withValues(alpha: 0.25),
            AppColors.surface.withValues(alpha: 0.55),
          ]),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  AppColors.amber.withValues(alpha: 0.4),
                  AppColors.amber.withValues(alpha: 0.1),
                ]),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.6)),
              ),
              child: const Icon(LucideIcons.users,
                  size: 18, color: AppColors.amber),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'group_call.inviteLabel'.tr(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.bronze),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'group_call.inviteTitle'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                        height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'group_call.inviteCta'.tr(),
                    style: AppTypography.body(
                        size: 11,
                        color: AppColors.amber,
                        weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(LucideIcons.phoneIncoming,
                  size: 16, color: AppColors.leben),
            ),
          ],
        ),
      ),
    );
  }
}
