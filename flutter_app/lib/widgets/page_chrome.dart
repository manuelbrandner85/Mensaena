import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Editorial-Page-Header — Pendant zum Web-Hero-Section-Pattern
/// (z. B. Crisis-Page, Events-Page mit Icon-Box + Untertitel).
/// Nutzbar als first child einer ListView/SliverList.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconBackground,
    this.iconColor,
    this.metaLabel,
    this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Hintergrund der Icon-Box. Default: primary500 mit alpha.
  final Color? iconBackground;

  /// Icon-Farbe. Default: primary500 oder iconBackground-Akzent.
  final Color? iconColor;

  /// Optionales All-Caps-Tag oben („KRISEN", „EVENTS" etc.)
  final String? metaLabel;

  /// Optionale rechte Action-Buttons (z. B. „Neu erstellen").
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary500;
    final bg = iconBackground ?? accent.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metaLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      metaLabel!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.ink400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Konsistentes Empty-State-Pattern – Pendant zum Web Empty-State-
/// Card mit Emoji + Titel + Subtext + CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(32, 48, 32, 48),
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.ink400,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 16),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton-Karte als Loading-Placeholder. Mehrere davon hintereinander
/// ergeben einen Skeleton-Feed. Pendant zu PostCardSkeleton.tsx.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 96});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(width: 56, height: 56, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 160, height: 14),
                  const SizedBox(height: 8),
                  _bar(width: double.infinity, height: 10),
                  const SizedBox(height: 6),
                  _bar(width: 220, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({double? width, required double height, double radius = 4}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.stone200,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Liste von SkeletonCards (typisch 4-6 Stück) für Loading-Feeds.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        for (int i = 0; i < count; i++) const SkeletonCard(),
      ],
    );
  }
}
