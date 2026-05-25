/// SKILL: mensaena-features
/// Reservation widget for the marketplace detail screen.
/// Behaviour based on 4 constellations:
///   1. Owner + reserved → confirm sale / cancel reservation
///   2. Other user + reserved_for == me → "Reserved for you" badge
///   3. Other user + reserved_for != me → "Already reserved" badge
///   4. Default (owner + not reserved, or anonymous) → nothing
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import '../repositories/marketplace_repository.dart';
import '../services/supabase_service.dart';
import 'confirm_dialog.dart';

class MarketplaceReservation extends ConsumerWidget {
  const MarketplaceReservation({
    required this.listingId,
    required this.ownerId,
    required this.reservedFor,
    super.key,
  });

  final String listingId;
  final String ownerId;
  final String? reservedFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return const SizedBox.shrink();
    final isOwner = me == ownerId;
    final isReservedForMe = reservedFor == me;
    final isReserved = reservedFor != null;

    // ── Case 1: Owner + reserved → confirm/unreserve buttons ──────────
    if (isOwner && isReserved) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.bookmark,
                  size: 16, color: AppColors.amber),
              const SizedBox(width: 8),
              Text('marketplace.reservation.activeOwner'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final ok = await ConfirmDialog.show(
                      context,
                      title: 'marketplace.reservation.confirmTitle'.tr(),
                      message: 'marketplace.reservation.confirmMsg'.tr(),
                    );
                    if (ok) {
                      await MarketplaceRepository.markAsClaimed(listingId);
                      ref.invalidate(marketplaceDetailProvider(listingId));
                    }
                  },
                  icon: const Icon(LucideIcons.checkCircle, size: 14),
                  label: Text('marketplace.reservation.confirmBtn'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.leben,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await MarketplaceRepository.unreserveListing(listingId);
                    ref.invalidate(marketplaceDetailProvider(listingId));
                  },
                  icon: const Icon(LucideIcons.xCircle, size: 14),
                  label: Text('marketplace.reservation.cancelBtn'.tr()),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    // ── Case 2: User is the reserved one ──────────────────────────────
    if (isReservedForMe) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.leben.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.leben.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(LucideIcons.heart, size: 18, color: AppColors.leben),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('marketplace.reservation.forYou'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.lebenSoft,
                        weight: FontWeight.w700)),
                Text('marketplace.reservation.forYouHint'.tr(),
                    style: AppTypography.caption()),
              ],
            ),
          ),
        ]),
      );
    }

    // ── Case 3: Reserved by someone else ──────────────────────────────
    if (isReserved && !isOwner) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.mute.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(LucideIcons.lock, size: 14, color: AppColors.mute),
          const SizedBox(width: 8),
          Text('marketplace.reservation.alreadyReserved'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.mute)),
        ]),
      );
    }

    // ── Default: nothing to show ──────────────────────────────────────
    return const SizedBox.shrink();
  }
}
