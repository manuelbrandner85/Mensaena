/// SKILL: mensaena-design
/// Shimmer-Skeleton-Library — Cinematic-Foundation Phase A.
///
/// Bietet Replica-Skeletons für die häufigsten Listen-Layouts:
///   - PostCardSkeleton   — wie eine PostCard aussieht, alles shimmernd.
///   - HeroImageSkeleton  — full-width 180dp Bild-Placeholder.
///   - ListSkeleton       — generische Liste mit Tile-Variante.
///
/// Bronze-Tönung statt grau für Konsistenz mit Cinema-Atmosphäre.
/// Bestehende `SkeletonCard`/`SkeletonList` (widgets/shared/skeleton_card.dart)
/// bleiben unverändert — diese Library ergänzt sie um Layout-spezifische
/// Skeletons mit höherem Fidelity-Level.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

/// Subtle-Bronze Shimmer-Box — animierter Linear-Gradient links→rechts.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = 8,
    this.duration = const Duration(milliseconds: 1400),
    super.key,
  });

  final double height;
  final double width;
  final double borderRadius;
  final Duration duration;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + t * 3.0, 0),
              end: Alignment(-0.5 + t * 3.0, 0),
              colors: [
                AppColors.elevated,
                AppColors.bronzeSoft.withValues(alpha: 0.18),
                AppColors.elevated,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Hero-Image-Placeholder — full-width 180dp, mit subtilem Bronze-Tint.
class HeroImageSkeleton extends StatelessWidget {
  const HeroImageSkeleton({
    this.height = 180,
    this.borderRadius = 14,
    super.key,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      height: height,
      borderRadius: borderRadius,
    );
  }
}

/// Replica einer PostCard — Avatar + Titel + 2 Text-Zeilen + Image-Block.
/// Layout matched ungefähr `widgets/post_card.dart`.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({
    this.showImage = true,
    this.margin = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  final bool showImage;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — Avatar + Author-Line + Time
          Row(
            children: [
              const ShimmerBox(width: 32, height: 32, borderRadius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 120, height: 11),
                    const SizedBox(height: 6),
                    ShimmerBox(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: 9,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Titel
          const ShimmerBox(height: 14),
          const SizedBox(height: 8),
          ShimmerBox(
            height: 14,
            width: MediaQuery.of(context).size.width * 0.7,
          ),
          const SizedBox(height: 12),
          // Optional Image-Block
          if (showImage) ...[
            const HeroImageSkeleton(height: 140, borderRadius: 10),
            const SizedBox(height: 12),
          ],
          // Footer Actions
          const Row(
            children: [
              ShimmerBox(width: 56, height: 10),
              SizedBox(width: 14),
              ShimmerBox(width: 56, height: 10),
              SizedBox(width: 14),
              ShimmerBox(width: 56, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Replica einer Notification-Tile — Icon-Box + 2 Text-Zeilen + Zeit-Stempel.
/// Layout matched `screens/dashboard/notifications_screen.dart` `_NotificationTile`.
class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 32, height: 32, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 12)),
                    SizedBox(width: 10),
                    ShimmerBox(
                      width: 36,
                      height: 9,
                      borderRadius: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const ShimmerBox(height: 10),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Replica eines Conversation-Tiles im Messages-Screen — runder Avatar +
/// Name + Preview-Zeile + Zeit + optional unread-Badge.
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 12, width: 140)),
                    SizedBox(width: 8),
                    ShimmerBox(width: 32, height: 9, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wiederholt eine Skeleton-Tile-Variante n-mal. Default = PostCardSkeleton.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    this.count = 5,
    this.padding = const EdgeInsets.all(12),
    this.tile,
    super.key,
  });

  final int count;
  final EdgeInsets padding;

  /// Optionaler Custom-Tile-Builder. Wenn null → PostCardSkeleton.
  final Widget Function(BuildContext context, int index)? tile;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: tile ??
          (_, i) => PostCardSkeleton(showImage: i.isEven),
    );
  }
}
