import 'package:flutter/material.dart';

/// Kaskade-Animation fuer Listen / Feeds: jedes Child fadet von unten
/// ein, mit konfigurierbarem Versatz (Default 50ms pro Index).
///
/// Verwendung:
///   CascadeFadeInUp(
///     index: 3,
///     child: NachbarschaftCard(...),
///   )
class CascadeFadeInUp extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerStep;
  final Duration duration;
  final double offsetY;

  const CascadeFadeInUp({
    super.key,
    required this.child,
    required this.index,
    this.staggerStep = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 350),
    this.offsetY = 16,
  });

  @override
  State<CascadeFadeInUp> createState() => _CascadeFadeInUpState();
}

class _CascadeFadeInUpState extends State<CascadeFadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.staggerStep * widget.index, () {
      if (mounted) _ctrl.forward();
    });
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
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - t)),
            child: widget.child,
          ),
        );
      },
    );
  }
}
