import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';

/// Bottom-Sheet im Cinema-Style: DragHandle, BackdropFilter, snap points.
class CinemaSheet {
  CinemaSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
    List<double> snapSizes = const [0.5, 0.9],
    double initialSize = 0.5,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: 0.25,
          maxChildSize: 0.95,
          snap: true,
          snapSizes: snapSizes,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: MnColors.raised,
              borderRadius: BorderRadius.vertical(top: Radius.circular(MnDimensions.radiusModal)),
            ),
            child: Column(
              children: [
                const _DragHandle(),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [child],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: MnColors.mute.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}
