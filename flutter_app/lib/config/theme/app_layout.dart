/// SKILL: mensaena-design (Phase 6 — Responsiveness)
/// AppLayout — Breakpoint-Tokens nach Material-3-Fensterklassen.
///
///   compact   < 600 dp   Phones, Foldable zugeklappt  → heutiges Layout
///   medium    600–839 dp Kleine Tablets, Foldable auf, Phone quer
///   expanded  ≥ 840 dp   Tablets quer
///
/// Verwendung (statt roher MediaQuery-Breiten-Vergleiche):
///   final layout = context.layout;
///   if (layout.isAtLeastMedium) ... // NavigationRail, Dialog statt Sheet
///   ConstrainedBox(constraints: BoxConstraints(
///       maxWidth: AppLayout.readableWidth), ...)   // Lesebreite ab medium
///
/// Regeln (CI-gestützt, siehe Phase-6-Plan):
///   - Grids: SliverGridDelegateWithMaxCrossAxisExtent statt fixem
///     crossAxisCount (Karte definiert Idealbreite, Spalten ergeben sich).
///   - Formulare/Artikel: maxWidth readableWidth zentriert ab medium.
library;

import 'package:flutter/widgets.dart';

enum AppLayoutClass { compact, medium, expanded }

class AppLayout {
  const AppLayout._();

  static const double mediumMin = 600;
  static const double expandedMin = 840;

  /// Maximale Lesebreite für Formulare/Fließtext auf großen Screens.
  static const double readableWidth = 640;

  /// Ideal-Kartenbreiten für Max-Extent-Grids (statt fixer Spaltenzahl).
  static const double cardExtent = 200; // kompakte Karten (Badges, Module)
  static const double tileExtent = 280; // grosse Karten (Marketplace, Events)

  static AppLayoutClass of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= expandedMin) return AppLayoutClass.expanded;
    if (w >= mediumMin) return AppLayoutClass.medium;
    return AppLayoutClass.compact;
  }
}

extension AppLayoutX on AppLayoutClass {
  bool get isCompact => this == AppLayoutClass.compact;
  bool get isAtLeastMedium => this != AppLayoutClass.compact;
  bool get isExpanded => this == AppLayoutClass.expanded;
}

extension AppLayoutContextX on BuildContext {
  AppLayoutClass get layout => AppLayout.of(this);
}
