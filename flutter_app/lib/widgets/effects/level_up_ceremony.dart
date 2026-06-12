/// SKILL: mensaena-design (Premium-Motion / Paket D Stolz-Momente)
/// LevelUpCeremony — der eine große Moment beim Karma-Levelwechsel
/// (Nachbar:in → Helfer:in → Stütze → Anker → Leuchtturm).
///
/// Emil-Prinzip: selten (max. 4x im Leben eines Accounts) → hier darf
/// Delight groß sein. Enter mit Overshoot (easeOutBack), Exit schnell.
/// EffectsGate: full = Glow + Stagger + Konfetti, reduced = Fade,
/// none = statischer Dialog (nur Haptik via CelebrateBurst-Fallback).
///
/// Guard: pro Gerät wird das zuletzt gefeierte Level in SecureStorage
/// gemerkt. Erste Beobachtung (Feature-Rollout/Neuinstallation) feiert
/// NICHT rückwirkend, sondern setzt nur die Basis.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/effects_gate_provider.dart';
import '../../services/karma_service.dart';
import 'celebrate_burst.dart';

const _seenKey = 'mensaena_karma_level_seen_v1';

class LevelUpCeremony {
  const LevelUpCeremony._();

  /// Prüft gegen das zuletzt gefeierte Level und zeigt die Zeremonie
  /// genau dann, wenn [level] höher ist. Idempotent + crash-sicher:
  /// Storage-Fehler → kein Dialog (lieber kein Fest als ein doppeltes).
  static Future<void> maybeShow(
    BuildContext context,
    WidgetRef ref,
    KarmaLevel level,
  ) async {
    const storage = FlutterSecureStorage();
    try {
      final raw = await storage.read(key: _seenKey);
      if (raw == null) {
        // Basis setzen, nicht rückwirkend feiern.
        await storage.write(key: _seenKey, value: '${level.index}');
        return;
      }
      final seen = int.tryParse(raw) ?? level.index;
      if (level.index <= seen) return;
      await storage.write(key: _seenKey, value: '${level.index}');
    } catch (_) {
      return;
    }
    if (!context.mounted) return;

    final profile = ref.read(effectsProfileProvider);
    final full = profile.isFull;
    // Konfetti zuerst — liegt im Overlay ÜBER dem Dialog-Barrier.
    CelebrateBurst.fire(context, ref: ref);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'karma.levelUp.title'.tr(),
      barrierColor: AppColors.sheetBackground,
      // Enter darf zelebrieren (380 ms), bleibt aber unter der
      // Modal-Obergrenze von 500 ms.
      transitionDuration: Duration(milliseconds: full ? 380 : 160),
      pageBuilder: (ctx, _, __) => _CeremonyCard(level: level, full: full),
      transitionBuilder: (ctx, anim, _, child) {
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        if (!full) return FadeTransition(opacity: fade, child: child);
        // Nie von scale(0): 0.92 → 1.0 mit Mini-Overshoot.
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}

class _CeremonyCard extends StatelessWidget {
  const _CeremonyCard({required this.level, required this.full});

  final KarmaLevel level;
  final bool full;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bronze.withValues(alpha: full ? 0.30 : 0.12),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Staggered(
                    enabled: full,
                    index: 0,
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bronze.withValues(alpha: 0.16),
                        border:
                            Border.all(color: AppColors.bronze, width: 1.5),
                      ),
                      child: const Icon(LucideIcons.award,
                          size: 36, color: AppColors.bronze),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Staggered(
                    enabled: full,
                    index: 1,
                    child: Text(
                      'karma.levelUp.title'.tr(),
                      style: AppTypography.caption(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Staggered(
                    enabled: full,
                    index: 2,
                    child: Text(
                      level.labelKey.tr(),
                      style: AppTypography.display(
                          size: 28, color: AppColors.bronze),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Staggered(
                    enabled: full,
                    index: 3,
                    child: Text(
                      'karma.levelUp.subtitle'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Staggered(
                    enabled: full,
                    index: 4,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.bronze,
                          foregroundColor: AppColors.voidColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'karma.levelUp.cta'.tr(),
                          style: AppTypography.body(
                              size: 14, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stagger im Dialog — bewusst controller-frei (TweenAnimationBuilder,
/// V23-Disziplin). 60 ms Versatz pro Element, je 260 ms easeOut.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.child,
    required this.index,
    required this.enabled,
  });

  final Widget child;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final start = (index * 0.12).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + index * 60),
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
