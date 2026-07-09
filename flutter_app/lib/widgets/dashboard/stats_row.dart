/// SKILL: mensaena-features
/// StatsRow — 4 animierte Stat-Cards (V14 als horizontale PageView mit Dots).
///
/// Auf breiten Screens (>=480px) als 4-Spalten-Grid; auf Phones als
/// horizontal-swipebarer PageView mit manueller Dot-Reihe.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_spacing.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../effects/tilt_card.dart';
import '../shared/stat_card.dart';

/// Datentupel fuer StatsRow — kapselt die 4 Werte plus Loading-Flag.
class StatsRowData {
  const StatsRowData({
    required this.profile,
    required this.unreadCount,
    required this.activeInteractions,
    required this.posts,
  });

  final Profile? profile;
  final int unreadCount;
  final int activeInteractions;
  final List<Post> posts;
}

class StatsRow extends StatefulWidget {
  const StatsRow({super.key, required this.data, required this.loading});
  final StatsRowData? data;
  final bool loading;

  @override
  State<StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<StatsRow> {
  final _controller = PageController(viewportFraction: 0.55);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _cards() {
    final d = widget.data;
    return [
      _AnimatedStatCard(
        icon: LucideIcons.mapPin,
        label: 'home.statNearby'.tr(),
        value: d?.posts.length ?? 0,
        accent: AppColors.bronze,
        loading: widget.loading,
      ),
      _AnimatedStatCard(
        icon: LucideIcons.bell,
        label: 'home.statUnread'.tr(),
        value: d?.unreadCount ?? 0,
        accent: AppColors.herzrot,
        loading: widget.loading,
      ),
      _AnimatedStatCard(
        icon: LucideIcons.helpingHand,
        label: 'home.statInteractions'.tr(),
        value: d?.activeInteractions ?? 0,
        accent: AppColors.teal,
        loading: widget.loading,
      ),
      _AnimatedStatCard(
        icon: LucideIcons.star,
        label: 'home.statTrust'.tr(),
        value: d?.profile?.trustScore ?? 0,
        accent: AppColors.trust,
        loading: widget.loading,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cards = _cards();
        if (c.maxWidth >= 480) {
          return GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
            children: cards,
          );
        }
        // Mobile: horizontal PageView mit Indicator-Dots.
        return Column(
          children: [
            SizedBox(
              height: 110,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                onPageChanged: (p) => setState(() => _page = p),
                itemCount: cards.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cards.length - 1 ? 0 : AppSpacing.xs,
                    ),
                    child: cards[i],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.bronze : AppColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  const _AnimatedStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return StatCard(
        icon: icon,
        label: label,
        value: '—',
        accent: accent,
        loading: true,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return TiltCard(
          intensity: 0.7,
          child: StatCard(
            icon: icon,
            label: label,
            value: '${v.round()}',
            accent: accent,
          ),
        );
      },
    );
  }
}
