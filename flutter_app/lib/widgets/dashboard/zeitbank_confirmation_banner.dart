import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/zeitbank_notification.dart';
import '../../repositories/timebank_repository.dart';

/// SKILL: mensaena-features
/// 1:1-Pendant zu `src/components/zeitbank/ZeitbankConfirmationBanner.tsx`.
/// Global banner — zeigt jedes unseen confirmation_request mit
/// Bestaetigen/Ablehnen-Buttons.
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
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final banners = list
            .where((n) => !_dismissed.contains(n.id))
            .toList();
        if (banners.isEmpty) return const SizedBox.shrink();
        return Container(
          margin:
              const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              for (final n in banners)
                _SingleBanner(
                  notif: n,
                  busy: _busyId == n.id,
                  onConfirm: () => _confirm(n),
                  onReject: () => _reject(n),
                  onDismiss: () => _dismiss(n),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirm(ZeitbankNotification n) async {
    setState(() => _busyId = n.id);
    final ok = await TimebankRepository.confirm(n.entryId);
    if (ok) await TimebankRepository.markNotificationSeen(n.id, clicked: true);
    if (!mounted) return;
    setState(() {
      _dismissed.add(n.id);
      _busyId = null;
    });
  }

  Future<void> _reject(ZeitbankNotification n) async {
    setState(() => _busyId = n.id);
    final ok = await TimebankRepository.reject(n.entryId);
    if (ok) await TimebankRepository.markNotificationSeen(n.id, clicked: true);
    if (!mounted) return;
    setState(() {
      _dismissed.add(n.id);
      _busyId = null;
    });
  }

  Future<void> _dismiss(ZeitbankNotification n) async {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.14),
            AppColors.bronzeSoft.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  size: 14, color: AppColors.bronze),
              const SizedBox(width: 6),
              Text('ZEITBANK-BESTÄTIGUNG',
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
            'Hast du diese Hilfe erhalten?',
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              height: 1.4,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ein Nachbar:in bittet um Bestätigung für die geleisteten Stunden.',
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
                  label: const Text('Ablehnen'),
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
                  label: const Text('Bestätigen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
