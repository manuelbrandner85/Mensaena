/// SKILL: mensaena-features (UX-Welle1 K3)
/// "Ich bin sicher"-Schnellbutton — analog WhatsApp-Status bei
/// Großschadenslagen. Sichtbar bei aktiven kritischen Krisen in der Nähe.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/crisis_repository.dart';
import '../../services/location_service.dart';

final _hasCriticalNearbyProvider =
    FutureProvider.autoDispose<({bool active, String? crisisId})>((ref) async {
  final latest = await CrisisRepository.latestCriticalActive();
  if (latest == null) return (active: false, crisisId: null);
  return (active: true, crisisId: latest['id'] as String?);
});

final _myCheckinTodayProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return CrisisRepository.myRecentSafeCheckin();
});

class SafeCheckinButton extends ConsumerWidget {
  const SafeCheckinButton({super.key});

  Future<void> _checkIn(BuildContext context, WidgetRef ref,
      String? crisisId) async {
    HapticFeedback.mediumImpact();
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 4));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {/* checkin works without GPS too */}
    final ok = await CrisisRepository.insertSafeCheckin(
      crisisId: crisisId,
      latitude: lat,
      longitude: lng,
    );
    if (ok) ref.invalidate(_myCheckinTodayProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(ok ? 'safe.confirmed'.tr() : 'common.failed'.tr(),
          style: AppTypography.body(
              size: 13, color: ok ? AppColors.leben : AppColors.ink)),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crisis = ref.watch(_hasCriticalNearbyProvider).maybeWhen(
          data: (c) => c,
          orElse: () => (active: false, crisisId: null),
        );
    if (!crisis.active) return const SizedBox.shrink();

    final alreadyChecked = ref.watch(_myCheckinTodayProvider).maybeWhen(
          data: (b) => b,
          orElse: () => false,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (alreadyChecked ? AppColors.leben : AppColors.herzrotWarm)
              .withValues(alpha: 0.14),
          border: Border.all(
              color: (alreadyChecked
                      ? AppColors.leben
                      : AppColors.herzrotWarm)
                  .withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(
            alreadyChecked
                ? LucideIcons.checkCircle2
                : LucideIcons.alertTriangle,
            size: 18,
            color: alreadyChecked
                ? AppColors.leben
                : AppColors.herzrotWarm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alreadyChecked
                      ? 'safe.checked_in_title'.tr()
                      : 'safe.critical_nearby_title'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700),
                ),
                Text(
                  alreadyChecked
                      ? 'safe.checked_in_hint'.tr()
                      : 'safe.critical_nearby_hint'.tr(),
                  style: AppTypography.body(
                      size: 11, color: AppColors.inkSoft, height: 1.3),
                ),
              ],
            ),
          ),
          if (!alreadyChecked)
            FilledButton(
              onPressed: () => _checkIn(context, ref, crisis.crisisId),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.leben,
                foregroundColor: AppColors.voidColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text('safe.button'.tr()),
            ),
        ]),
      ),
    );
  }
}
