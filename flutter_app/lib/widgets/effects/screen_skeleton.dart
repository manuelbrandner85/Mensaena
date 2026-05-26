/// SKILL: mensaena-features
/// ScreenSkeleton (V18) — full-screen Cinematic loading skeleton.
///
/// Higher-fidelity than `ShimmerBox` / `PostCardSkeleton`: it lays out a
/// realistic full-screen placeholder for the major Mensaena surfaces
/// (Dashboard, Chat, Map, Profile, generic List) using the existing
/// `ShimmerBox` from `shimmer_skeleton.dart` and a subtle `FilmGrainOverlay`
/// + `VignetteOverlay` so even the loading state feels cinematic.
///
/// Use the factory constructors for the canonical shapes:
///   - `ScreenSkeleton.dashboard()` — header + stats + list
///   - `ScreenSkeleton.chat()`      — bubble stream
///   - `ScreenSkeleton.map()`       — full-bleed image + control rail
///   - `ScreenSkeleton.profile()`   — avatar + stats + bio
///   - `ScreenSkeleton.list(count:) — n generic rows
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import 'film_grain.dart';
import 'shimmer_skeleton.dart';
import 'vignette.dart';

class ScreenSkeleton extends StatelessWidget {
  const ScreenSkeleton({
    this.lines = 4,
    this.hasImage = false,
    this.hasHeader = true,
    this.hasStats = false,
    super.key,
  });

  /// Number of body lines / list rows to render.
  final int lines;

  /// Render a hero image block at the top.
  final bool hasImage;

  /// Render a title / subtitle header above the body.
  final bool hasHeader;

  /// Render a 3-up stat row beneath the header.
  final bool hasStats;

  // ── Named factories (return Widget) ────────────────────────────────
  // The specialised skeletons are private subclasses, so the factories
  // expose them as plain Widgets. Callers don't care about the concrete
  // type — they just want a ready-to-paint placeholder.

  /// Dashboard skeleton — header + 3 stat tiles + 5 post placeholders.
  static Widget dashboard() => const ScreenSkeleton(
        hasHeader: true,
        hasStats: true,
        hasImage: false,
        lines: 5,
      );

  /// Chat skeleton — list of alternating speech-bubble placeholders.
  static Widget chat() => const _ChatScreenSkeleton();

  /// Map skeleton — full-bleed shimmering tile with a control rail.
  static Widget map() => const _MapScreenSkeleton();

  /// Profile skeleton — avatar + 3 stat tiles + bio.
  static Widget profile() => const _ProfileScreenSkeleton();

  /// Generic list — n rows of PostCardSkeleton.
  static Widget list({int count = 5}) =>
      ScreenSkeleton(hasHeader: false, hasStats: false, lines: count);

  @override
  Widget build(BuildContext context) {
    return _CinematicScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (hasHeader) ...[
            const ShimmerBox(height: 28, width: 220),
            const SizedBox(height: 10),
            const ShimmerBox(height: 14, width: 160),
            const SizedBox(height: 20),
          ],
          if (hasStats) ...[
            const _StatsRow(),
            const SizedBox(height: 20),
          ],
          if (hasImage) ...[
            const HeroImageSkeleton(),
            const SizedBox(height: 20),
          ],
          for (var i = 0; i < lines; i++)
            PostCardSkeleton(showImage: i.isEven),
        ],
      ),
    );
  }
}

/// Wraps a child in the dark Cinema background with subtle grain + vignette.
class _CinematicScaffold extends StatelessWidget {
  const _CinematicScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.voidColor,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned.fill(
            child: IgnorePointer(
              child: FilmGrainOverlay(opacity: 0.02),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: VignetteOverlay(intensity: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ShimmerBox(height: 72, borderRadius: 12)),
        SizedBox(width: 10),
        Expanded(child: ShimmerBox(height: 72, borderRadius: 12)),
        SizedBox(width: 10),
        Expanded(child: ShimmerBox(height: 72, borderRadius: 12)),
      ],
    );
  }
}

// ── Specialised skeletons ────────────────────────────────────────────

class _ChatScreenSkeleton extends StatelessWidget {
  const _ChatScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return _CinematicScaffold(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (_, i) {
          final mine = i.isOdd;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment:
                  mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!mine)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ShimmerBox(
                      width: 28,
                      height: 28,
                      borderRadius: 14,
                    ),
                  ),
                ShimmerBox(
                  width: MediaQuery.sizeOf(context).width *
                      (mine ? 0.45 : 0.6),
                  height: 44,
                  borderRadius: 14,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MapScreenSkeleton extends StatelessWidget {
  const _MapScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return _CinematicScaffold(
      child: Stack(
        children: [
          const Positioned.fill(
            child: ShimmerBox(borderRadius: 0),
          ),
          Positioned(
            right: 16,
            top: 24,
            child: Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ShimmerBox(
                    width: 42,
                    height: 42,
                    borderRadius: 12,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 64, borderRadius: 14),
                SizedBox(height: 10),
                ShimmerBox(height: 64, borderRadius: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileScreenSkeleton extends StatelessWidget {
  const _ProfileScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return _CinematicScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Center(
            child: ShimmerBox(width: 96, height: 96, borderRadius: 48),
          ),
          SizedBox(height: 14),
          Center(child: ShimmerBox(width: 180, height: 18)),
          SizedBox(height: 8),
          Center(child: ShimmerBox(width: 120, height: 12)),
          SizedBox(height: 24),
          _StatsRow(),
          SizedBox(height: 20),
          ShimmerBox(height: 12),
          SizedBox(height: 8),
          ShimmerBox(height: 12, width: 260),
          SizedBox(height: 8),
          ShimmerBox(height: 12, width: 200),
          SizedBox(height: 24),
          PostCardSkeleton(showImage: true),
          PostCardSkeleton(showImage: false),
        ],
      ),
    );
  }
}
