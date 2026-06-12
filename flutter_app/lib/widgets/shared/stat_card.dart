import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/device_tier_service.dart';
import 'count_up_text.dart';

/// SKILL: mensaena-design
/// Statistik-Kachel fuer Dashboard-Home. Icon + Label + Wert.
/// Welten-inspired glass banner: BackdropFilter blur, akzentfarbiger
/// Seiten-Strich + Glow-Hintergrund, innerer Highlight-Streifen oben.
/// Tier-aware: auf Lite-Geraeten ohne BackdropFilter (BackdropFilter ist auf
/// alten ARM-Geraeten teuer), aber visuell sehr aehnlich durch Glass-Tint.
class StatCard extends ConsumerWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.amber,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lite = ref.watch(liteModeActiveProvider);
    final inner = _innerCard();
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: lite
          ? inner
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: inner,
            ),
    );
    // Outer container carries the glow + accent left-border.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _innerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Glass tint: light translucent surface + soft accent wash top-left.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            AppColors.surface.withValues(alpha: 0.55),
          ],
        ),
        // Accent left bar via a directional border -- reads as a glass edge.
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.85), width: 2.5),
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          right: BorderSide(color: accent.withValues(alpha: 0.18)),
          bottom: BorderSide(color: accent.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        children: [
          // Inner highlight strip top (mimics light catching glass).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.40),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: AppTypography.label(size: 10),
              ),
              const SizedBox(height: 6),
              // E2: Skeleton -> Wert nicht hart tauschen, sondern kurzer
              // Crossfade (150 ms, ease-out). B4: Wert zählt hoch.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                child: loading
                    ? Container(
                        key: const ValueKey('skeleton'),
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : CountUpText(
                        value,
                        key: const ValueKey('value'),
                        style: AppTypography.mono(
                          size: 24,
                          weight: FontWeight.w700,
                        ).copyWith(color: AppColors.ink),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
