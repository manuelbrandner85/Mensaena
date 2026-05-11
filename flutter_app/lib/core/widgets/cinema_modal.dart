import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/shadows.dart';
import '../theme/typography.dart';

/// Cinema-Modal: BackdropFilter blur, raised bg, slideUp + scale Animation.
class CinemaModal extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;

  const CinemaModal({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.maxWidth = 440,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 440,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Modal schliessen',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) {
        return CinemaModal(
          title: title,
          actions: actions,
          maxWidth: maxWidth,
          child: child,
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final c = Curves.easeOutCubic.transform(anim.value);
        return Stack(
          children: [
            Opacity(
              opacity: c,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12 * c, sigmaY: 12 * c),
                child: Container(color: Colors.black.withValues(alpha: 0.6 * c)),
              ),
            ),
            Center(
              child: Opacity(
                opacity: c,
                child: Transform.scale(
                  scale: 0.95 + 0.05 * c,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MnColors.raised,
              borderRadius: BorderRadius.circular(MnDimensions.radiusModal),
              boxShadow: MnShadows.raised,
              border: Border.all(color: MnColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 12, 0),
                          child: Text(title!, style: MnTypography.display(size: 22)),
                        ),
                      )
                    else
                      const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
                      child: IconButton(
                        icon: const Icon(LucideIcons.x, color: MnColors.mute, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: child,
                  ),
                ),
                if (actions != null && actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (int i = 0; i < actions!.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          actions![i],
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
