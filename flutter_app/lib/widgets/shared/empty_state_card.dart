import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Empty-State-Card mit Icon, Titel, Beschreibung und optionalem CTA.
/// Premium: das Icon "atmet" (sanfter Glow-Puls) — lebendig statt statisch.
class EmptyStateCard extends StatefulWidget {
  const EmptyStateCard({
    required this.title,
    this.description,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.color,
    this.moodAsset,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  /// Optionales Higgsfield-Stimmungsbild (assets/images/empty_*.webp) —
  /// macht aus dem leeren Zustand einen Moment statt einer Luecke.
  final String? moodAsset;

  @override
  State<EmptyStateCard> createState() => _EmptyStateCardState();
}

class _EmptyStateCardState extends State<EmptyStateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppColors.amber;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        // Dezenter Akzent-Verlauf gibt dem leeren Zustand Atmosphäre statt
        // flacher Box.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.06),
            AppColors.surface.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (widget.moodAsset != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // E3: Ken-Burns-Mini-Drift auf dem Stimmungsbild — teilt
              // sich den vorhandenen Puls-Controller (kein 2. Ticker),
              // Transform-only, der Clip frisst den Überstand.
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + _pulse.value * 0.03,
                  child: child,
                ),
                child: Image.asset(
                  widget.moodAsset!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Fehler -> Bild faellt einfach weg, Layout bleibt intakt.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final t = _pulse.value;
              return SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Atmender Außenring.
                    Container(
                      width: 72 + t * 12,
                      height: 72 + t * 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.10 + t * 0.18),
                          width: 1,
                        ),
                      ),
                    ),
                    // Glühender Orb mit Radial-Gradient.
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          accent.withValues(alpha: 0.28 + t * 0.10),
                          accent.withValues(alpha: 0.06),
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.14 + t * 0.22),
                            blurRadius: 18 + t * 16,
                            spreadRadius: t * 3,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ],
                ),
              );
            },
            child: Icon(widget.icon, color: accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: 19,
              color: AppColors.ink,
            ),
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.description!,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 12,
                color: AppColors.inkSoft,
                height: 1.55,
              ),
            ),
          ],
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppColors.voidColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onPressed: widget.onAction,
              child: Text(widget.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
