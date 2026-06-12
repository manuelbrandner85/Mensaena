/// SKILL: mensaena-design (Cinema-Hyperreal)
/// Pressable — dezenter Scale-Down beim Drücken für Cards & Buttons.
/// Gibt der App das taktile, hochwertige Cinema-Feel-Gefühl ohne pro
/// Aufrufstelle eigene AnimationController zu bauen.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/motion/app_motion.dart';
import '../../services/haptics.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.borderRadius,
    this.glow,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;

  /// Optional: Glow-Farbe beim Drücken (für Primär-Aktionen). Null = kein Glow.
  final Color? glow;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _scaleCtrl =
      AnimationController.unbounded(vsync: this, value: 1.0);

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _set(bool v) {
    if (!mounted || _down == v) return;
    setState(() => _down = v);
    // Physik statt fixer Duration: Druecken schnappt straff zu (snappy),
    // Loslassen federt mit minimalem Overshoot zurueck (bouncy) — das
    // "lebendige" Release ist der Kern des Engine-Feels.
    _scaleCtrl.springTo(
      v ? widget.scale : 1.0,
      spring: v ? AppMotion.snappy : AppMotion.bouncy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleCtrl,
        child: widget.glow == null
            ? widget.child
            : AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(14),
                  boxShadow: _down
                      ? [
                          BoxShadow(
                            color: (widget.glow ?? AppColors.bronze)
                                .withValues(alpha: 0.45),
                            blurRadius: 22,
                            spreadRadius: -2,
                          ),
                        ]
                      : const [],
                ),
                child: widget.child,
              ),
      ),
    );
  }
}
