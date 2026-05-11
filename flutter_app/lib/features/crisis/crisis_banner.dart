import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/crisis_provider.dart';

/// Banner direkt unter der AppBar — sichtbar wenn eine Krise aktiv ist.
/// Liest crisis_provider und blendet sich ueberall global ein.
class CrisisBanner extends ConsumerWidget {
  const CrisisBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crisis = ref.watch(primaryCrisisProvider);
    if (crisis == null) return const SizedBox.shrink();

    final desc = (crisis['description'] as String?) ?? 'Krisenmodus aktiv';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MnColors.herzrot.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: MnColors.herzrot.withValues(alpha: 0.30),
          ),
        ),
      ),
      child: Row(
        children: [
          _PulsingIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Krisenmodus: $desc',
              style: MnTypography.body(
                color: MnColors.ink,
                size: 13,
                weight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GlowButton(
            label: 'Helfen',
            variant: GlowVariant.crisis,
            compact: true,
            onPressed: () => GoRouter.of(context)
                .push('/posts/new?category=krisenhilfe'),
          ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
        final t = (_ctrl.value * 2 - 1).abs(); // 0..1..0
        return Icon(
          LucideIcons.alertTriangle,
          size: 20,
          color: MnColors.herzrotWarm,
          shadows: [
            Shadow(
              color: MnColors.herzrot.withValues(alpha: 0.4 + t * 0.4),
              blurRadius: 8 + t * 8,
            ),
          ],
        );
      },
    );
  }
}
