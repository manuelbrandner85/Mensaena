/// SKILL: mensaena-features (Dashboard-Edit)
/// Wrapper im Edit-Mode: Jiggle-Anim + ❌-Button + Drag-Handle.
/// Respektiert A11yPrefs.reduceMotion (kein Wackeln dann).
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/accessibility_provider.dart';
import 'widget_grid_settings.dart';

class DashboardWidgetWrapper extends ConsumerStatefulWidget {
  const DashboardWidgetWrapper({
    required this.widgetId,
    required this.isEditMode,
    required this.dragIndex,
    required this.child,
    super.key,
  });

  final String widgetId;
  final bool isEditMode;

  /// Index für ReorderableDragStartListener.
  final int dragIndex;
  final Widget child;

  @override
  ConsumerState<DashboardWidgetWrapper> createState() =>
      _DashboardWidgetWrapperState();
}

class _DashboardWidgetWrapperState
    extends ConsumerState<DashboardWidgetWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jiggle;

  @override
  void initState() {
    super.initState();
    _jiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isEditMode) _jiggle.repeat();
  }

  @override
  void didUpdateWidget(covariant DashboardWidgetWrapper old) {
    super.didUpdateWidget(old);
    if (widget.isEditMode && !_jiggle.isAnimating) {
      _jiggle.repeat();
    } else if (!widget.isEditMode && _jiggle.isAnimating) {
      _jiggle.stop();
    }
  }

  @override
  void dispose() {
    _jiggle.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(dashboardWidgetConfigProvider.notifier);
    await notifier.disableWidget(widget.widgetId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      duration: const Duration(seconds: 3),
      content: Text('dashboard.edit.widget_disabled'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink)),
      action: SnackBarAction(
        label: 'common.undo'.tr(),
        textColor: AppColors.bronze,
        onPressed: () => notifier.enableWidget(widget.widgetId),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditMode) return widget.child;

    final reduceMotion = ref.watch(a11yProvider).effectiveReduceMotion;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Jiggle nur wenn reduceMotion=false
        AnimatedBuilder(
          animation: _jiggle,
          builder: (_, child) {
            if (reduceMotion) return child!;
            final angle =
                math.sin(_jiggle.value * 2 * math.pi) * 0.015; // ±0.86°
            return Transform.rotate(angle: angle, child: child);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.bronze.withValues(alpha: 0.3),
                  width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.child,
            ),
          ),
        ),
        // Disable-Button oben-links
        Positioned(
          top: -6,
          left: -2,
          child: GestureDetector(
            onTap: _disable,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.herzrotWarm,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(LucideIcons.x,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
        // Drag-Handle oben-rechts
        Positioned(
          top: -4,
          right: -2,
          child: ReorderableDragStartListener(
            index: widget.dragIndex,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(LucideIcons.gripVertical,
                  size: 16, color: AppColors.bronze),
            ),
          ),
        ),
      ],
    );
  }
}
