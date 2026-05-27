/// SKILL: mensaena-features (UX-Welle1 P2)
/// Freundschaftsanfrage-Button auf einem fremden Profil.
/// Zustands-abhängig: Anfragen / Anfrage gesendet / Anfrage annehmen /
/// Befreundet / Wieder-anfragen (nach declined).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/friendships_repository.dart';
import '../effects/celebrate_burst.dart';

final friendshipStateProvider = FutureProvider.autoDispose
    .family<FriendshipState, String>((ref, otherId) async {
  return FriendshipsRepository.stateWith(otherId);
});

class FriendRequestButton extends ConsumerWidget {
  const FriendRequestButton({required this.userId, super.key});
  final String userId;

  Future<void> _action(WidgetRef ref, BuildContext context,
      FriendshipState state) async {
    HapticFeedback.lightImpact();
    bool ok = false;
    String message = '';
    switch (state) {
      case FriendshipState.none:
      case FriendshipState.declined:
        ok = await FriendshipsRepository.request(userId);
        message = ok ? 'friend.request_sent'.tr() : 'friend.request_failed'.tr();
        break;
      case FriendshipState.outgoingPending:
        ok = await FriendshipsRepository.remove(userId);
        message = ok ? 'friend.request_canceled'.tr() : 'friend.request_failed'.tr();
        break;
      case FriendshipState.incomingPending:
        ok = await FriendshipsRepository.accept(userId);
        message = ok ? 'friend.accepted'.tr() : 'friend.request_failed'.tr();
        // ZUSATZ-4E: Konfetti nach erfolgreicher Annahme.
        if (ok && context.mounted) {
          CelebrateBurst.fire(context, ref: ref);
        }
        break;
      case FriendshipState.accepted:
        // Confirm-Dialog vor "Freundschaft beenden"
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('friend.unfriend_title'.tr(),
                style: AppTypography.display(size: 16, color: AppColors.ink)),
            content: Text('friend.unfriend_body'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.herzrotWarm),
                child: Text('friend.unfriend_confirm'.tr()),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        ok = await FriendshipsRepository.remove(userId);
        message = ok ? 'friend.removed'.tr() : 'friend.request_failed'.tr();
        break;
    }
    ref.invalidate(friendshipStateProvider(userId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(message,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendshipStateProvider(userId)).maybeWhen(
          data: (s) => s,
          orElse: () => FriendshipState.none,
        );
    final (label, icon, color) = switch (state) {
      FriendshipState.none => ('friend.request'.tr(), LucideIcons.userPlus, AppColors.bronze),
      FriendshipState.declined => ('friend.request_again'.tr(), LucideIcons.userPlus, AppColors.bronze),
      FriendshipState.outgoingPending => ('friend.requested'.tr(), LucideIcons.clock, AppColors.mute),
      FriendshipState.incomingPending => ('friend.accept'.tr(), LucideIcons.userCheck, AppColors.leben),
      FriendshipState.accepted => ('friend.friends'.tr(), LucideIcons.userCheck, AppColors.leben),
    };
    return FilledButton.icon(
      onPressed: () => _action(ref, context, state),
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
