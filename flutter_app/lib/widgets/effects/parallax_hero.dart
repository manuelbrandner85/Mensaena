/// SKILL: mensaena-design
/// Parallax-Hero — Hintergrund-Layer bewegt sich beim Scroll langsamer als
/// der Vordergrund. Faktor 0.4 (40 % der Scroll-Distanz).
/// Erzeugt Tiefen-Eindruck wie iOS-Wallpaper-Parallax.
library;

import 'package:flutter/material.dart';

class ParallaxHero extends StatefulWidget {
  const ParallaxHero({
    required this.background,
    required this.foreground,
    required this.scrollController,
    this.factor = 0.4,
    this.height = 240,
    super.key,
  });

  final Widget background;
  final Widget foreground;
  final ScrollController scrollController;

  /// 0.0 = kein Parallax, 1.0 = mitbewegt mit Vordergrund.
  /// Default 0.4 = Hintergrund bewegt sich um 60 % weniger.
  final double factor;

  final double height;

  @override
  State<ParallaxHero> createState() => _ParallaxHeroState();
}

class _ParallaxHeroState extends State<ParallaxHero> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final o = widget.scrollController.offset;
    if (o > widget.height) return; // außerhalb sichtbar
    setState(() => _offset = o);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned(
            top: -_offset * widget.factor,
            left: 0,
            right: 0,
            height: widget.height,
            child: widget.background,
          ),
          widget.foreground,
        ],
      ),
    );
  }
}
