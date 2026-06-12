/// SKILL: mensaena-design (Phase 6 — Responsiveness)
/// ReadableWidth — begrenzt Formulare/Fließtext auf eine Lesebreite
/// (AppLayout.readableWidth = 640 dp) und zentriert sie.
///
/// Auf Phones (compact) wirkungslos (Breite < 640) — auf Tablets/
/// Foldables laufen Eingabefelder nicht mehr über die volle Breite.
/// Der billigste Tablet-Gewinn: ein Wrapper, kein Layout-Umbau.
///
///   body: ReadableWidth(child: ListView(...))
library;

import 'package:flutter/widgets.dart';

import '../../config/theme/app_layout.dart';

class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, this.maxWidth, super.key});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppLayout.readableWidth,
        ),
        child: child,
      ),
    );
  }
}
