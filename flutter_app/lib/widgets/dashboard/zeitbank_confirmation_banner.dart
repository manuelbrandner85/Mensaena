import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/zeitbank_notification.dart';
import '../../repositories/timebank_repository.dart';
import '../../services/haptics.dart';
import '../effects/glass_card.dart';
import 'tile_error.dart';

/// SKILL: mensaena-features
/// Globaler Zeitbank-Confirmation-Banner. Streamt `zeitbank_notifications` mit
/// `type=confirmation_request` und `seen=false` fuer den aktuellen User.
///
/// V2 (Phase 2):
///   - GlassCard mit amber Glow-Shadow
///   - Slide-in von oben mit AnimatedSwitcher (350ms easeOutCubic)
///   - Haptics auf Accept/Decline (success/error) und Dismiss (tap)
class ZeitbankConfirmationBanner extends ConsumerStatefulWidget {
  const ZeitbankConfirmationBanner({super.key});

  @override
  ConsumerState<ZeitbankConfirmationBanner> createState() =>
      _ZeitbankConfirmationBannerState();
}

class _ZeitbankConfirmationBannerState
    extends ConsumerState<ZeitbankConfirmationBanner> {
  final Set<String> _dismissed = {};
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(zeitbankNotificationsStreamProvider);
    return stream.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(zeitbankNotificationsStreamProvider)),
      data: (list) {
        final banners = list
            .where((n) => !_dismissed.contains(n.id))
            .toList();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, -1.1),
              end: Offset.zero,
            ).animate(animation);
            return ClipRect(
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              ),
            );
          },
          child: banners.isEmpty
              ? const SizedBox.shrink(key: ValueKey('zb-empty'))
              : Padding(
                  key: ValueKey('zb-list-${banners.length}-${banners.first.id}'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      for (final n in banners)
                        _SingleBanner(
                          key: ValueKey('zb-${n.id}'),
                          notif: n,
                          busy: _busyId == n.id,
                          onConfirm: () => _confirm(n),
                          onReject: () => _reject(n),
                          onDismiss: () => _dismiss(n),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirm(ZeitbankNotification n) async {
    Haptics.confirm();
    setState(() => _busyId = n.id);
    final ok = await TimebankRepository.confirm(n.entryId);
    if (ok) {
      await TimebankRepository.markNotificationSeen(n.id, clicked: true);
      await Haptics.success();
    } else {
      await Haptics.error();
    }
    if (!mounted) return;
    setState(() {
      _dismissed.add(n.id);
      _busyId = null;
    });
  }

  Future<void> _reject(ZeitbankNotification n) async {
    Haptics.tap();
    setState(() => _busyId = n.id);
    final ok = await TimebankRepository.reject(n.entryId);
    if (ok) {
      await TimebankRepository.markNotificationSeen(n.id, clicked: true);
    }
    await Haptics.error();
    if (!mounted) return;
    setState(() {
      _dismissed.add(n.id);
      _busyId = null;
    });
  }

  Future<void> _dismiss(ZeitbankNotification n) async {
    Haptics.tap();
    await TimebankRepository.markNotificationSeen(n.id);
    if (!mounted) return;
    setState(() => _dismissed.add(n.id));
  }
}

class _SingleBanner extends StatelessWidget {
  const _SingleBanner({
    required this.notif,
    required this.busy,
    required this.onConfirm,
    required this.onReject,
    required this.onDismiss,
    super.key,
  });

  final ZeitbankNotification notif;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 14,
        borderColor: AppColors.bronze.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clock,
                    size: 14, color: AppColors.bronze),
                const SizedBox(width: 6),
                Text('timebank.zeitbankConfirmation'.tr(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.bronze)),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(LucideIcons.x,
                      size: 14, color: AppColors.mute),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'timebank.confirmHelpQuestion'.tr(),
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                height: 1.4,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'timebank.confirmHelpHint'.tr(),
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.herzrotWarm,
                      side: BorderSide(
                          color: AppColors.herzrot
                              .withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(LucideIcons.x, size: 14),
                    label: Text('common.reject'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.bronze,
                      foregroundColor: AppColors.voidColor,
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.voidColor,
                            ),
                          )
                        : const Icon(LucideIcons.check, size: 14),
                    label: Text('common.confirm'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
