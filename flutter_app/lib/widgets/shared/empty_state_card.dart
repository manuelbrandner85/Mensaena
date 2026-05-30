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
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final t = _pulse.value;
              return Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10 + t * 0.08),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.10 + t * 0.22),
                      blurRadius: 12 + t * 12,
                      spreadRadius: t * 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Icon(widget.icon, color: accent, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w700,
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
