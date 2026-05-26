/// SKILL: mensaena-features (Performance P27)
/// Sammlung von Skeleton-Templates die in Loading-States statt
/// CircularProgressIndicator genutzt werden können.
///
/// Nutzung:
///   if (snapshot.isLoading) return const PostListSkeleton(count: 5);
///
/// Dimensionen MÜSSEN den echten Widgets entsprechen damit kein
/// Layout-Shift entsteht.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/theme/app_colors.dart';
import '../../providers/accessibility_provider.dart';

/// Statisches Graphik-Pellet ohne Shimmer (für reduceMotion-Modus).
class _StaticBox extends StatelessWidget {
  const _StaticBox({this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wrapper der Shimmer ODER statisches Grau zurückgibt — abhängig von
/// A11yPrefs.effectiveReduceMotion.
class _ShimmerBox extends ConsumerWidget {
  const _ShimmerBox({this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion =
        ref.watch(a11yProvider.select((p) => p.effectiveReduceMotion));
    final box = _StaticBox(width: width, height: height, radius: radius);
    if (reduceMotion) return box;
    return Shimmer.fromColors(
      baseColor: AppColors.elevated.withValues(alpha: 0.6),
      highlightColor: AppColors.elevated.withValues(alpha: 0.9),
      period: const Duration(milliseconds: 1400),
      child: box,
    );
  }
}

/// Post-Card-Skeleton — passt zur PostCard-Größe im Feed.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _ShimmerBox(width: 36, height: 36, radius: 18),
            SizedBox(width: 10),
            Expanded(child: _ShimmerBox(height: 12)),
          ]),
          SizedBox(height: 10),
          _ShimmerBox(height: 180, radius: 12),
          SizedBox(height: 10),
          _ShimmerBox(height: 14),
          SizedBox(height: 6),
          _ShimmerBox(height: 14, width: 200),
        ],
      ),
    );
  }
}

class PostListSkeleton extends StatelessWidget {
  const PostListSkeleton({this.count = 4, super.key});
  final int count;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: count,
      itemBuilder: (_, __) => const PostCardSkeleton(),
    );
  }
}

class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        _ShimmerBox(width: 96, height: 96, radius: 48),
        SizedBox(height: 12),
        _ShimmerBox(width: 180, height: 18),
        SizedBox(height: 8),
        _ShimmerBox(width: 220, height: 12),
      ]),
    );
  }
}

class CommentTileSkeleton extends StatelessWidget {
  const CommentTileSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _ShimmerBox(width: 28, height: 28, radius: 14),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(height: 12, width: 100),
              SizedBox(height: 6),
              _ShimmerBox(height: 12),
            ],
          ),
        ),
      ]),
    );
  }
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(children: [
        _ShimmerBox(width: 72, height: 72, radius: 10),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(height: 14, width: 180),
              SizedBox(height: 8),
              _ShimmerBox(height: 12, width: 120),
              SizedBox(height: 6),
              _ShimmerBox(height: 12, width: 90),
            ],
          ),
        ),
      ]),
    );
  }
}

class MarketplaceCardSkeleton extends StatelessWidget {
  const MarketplaceCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: _ShimmerBox(height: 140, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(height: 12),
                SizedBox(height: 6),
                _ShimmerBox(height: 14, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubbleSkeleton extends StatelessWidget {
  const ChatBubbleSkeleton({this.mine = false, super.key});
  final bool mine;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        width: 200,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const _ShimmerBox(radius: 16),
      ),
    );
  }
}
