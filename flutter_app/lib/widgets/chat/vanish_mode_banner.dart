/// SKILL: mensaena-features (P2) — Vanish-Mode Hinweis-Banner im Chat.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';

final _vanishStateProvider =
    FutureProvider.autoDispose.family<({bool enabled, int seconds}), String>(
        (ref, conversationId) async {
  try {
    return ConversationsRepository.vanishSettings(conversationId);
  } catch (_) {
    return (enabled: false, seconds: 3600);
  }
});

class VanishModeBanner extends ConsumerWidget {
  const VanishModeBanner({required this.conversationId, super.key});
  final String conversationId;

  String _label(int s) {
    if (s < 3600) return '${(s / 60).round()} min';
    if (s < 86400) return '${(s / 3600).round()} h';
    return '${(s / 86400).round()} d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_vanishStateProvider(conversationId)).maybeWhen(
          data: (v) {
            if (!v.enabled) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(LucideIcons.eyeOff,
                    size: 14, color: AppColors.bronze),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'vanish.banner'.tr(
                        namedArgs: {'duration': _label(v.seconds)}),
                    style: AppTypography.body(
                        size: 12, color: AppColors.bronze),
                  ),
                ),
              ]),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
