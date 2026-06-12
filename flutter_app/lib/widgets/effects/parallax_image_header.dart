/// SKILL: mensaena-design (Cinema-Hyperreal)
/// Wiederverwendbarer Parallax-Bild-Header für Detail-Screens.
///
/// Das Bild scrollt langsamer als der Content (Faktor 0.4) und bekommt einen
/// Bottom-Scrim-Gradient für filmische Tiefe. Erwartet den ScrollController
/// der umgebenden scrollbaren Liste — bewegt sich nur solange der Header
/// sichtbar ist (Offset < height + 60), danach kein setState mehr (PERF).
///
/// Nur Transform + Gradient → GPU-leicht, ARM32/64-tauglich.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class ParallaxImageHeader extends StatefulWidget {
  const ParallaxImageHeader({
    required this.child,
    required this.scrollController,
    this.height = 240,
    this.borderRadius = 14,
    this.factor = 0.4,
    this.scrimAlpha = 0.55,
    super.key,
  });

  /// Das Bild/Carousel, das parallax-versetzt wird.
  final Widget child;
  final ScrollController scrollController;
  final double height;
  final double borderRadius;

  /// 0.0 = kein Parallax, 1.0 = bewegt sich voll mit. 0.4 = 60 % langsamer.
  final double factor;

  /// Deckkraft des Bottom-Scrims (voidColor).
  final double scrimAlpha;

  @override
  State<ParallaxImageHeader> createState() => _ParallaxImageHeaderState();
}

class _ParallaxImageHeaderState extends State<ParallaxImageHeader> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ParallaxImageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tauscht der Parent den ScrollController, MUSS der Listener umziehen
    // — sonst feuert _onScroll doppelt bzw. auf einem toten Controller.
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final o = widget.scrollController.offset;
    if (o > widget.height + 60) return; // Header außer Sicht → nicht updaten
    setState(() => _offset = o);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, -_offset * widget.factor),
              child: Transform.scale(
                // Overscale verhindert sichtbare Kante beim Parallax-Shift.
                scale: 1.12,
                child: widget.child,
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.voidColor.withValues(alpha: widget.scrimAlpha),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
