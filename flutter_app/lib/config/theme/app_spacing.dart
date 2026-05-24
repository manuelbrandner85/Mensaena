/// SKILL: mensaena-design
/// Spacing-System — alle Paddings/Margins als Multiples von 4dp.
/// 1:1 zu Web tailwind (space-1=4px, space-2=8px etc.)
///
/// Verwendung: `EdgeInsets.all(AppSpacing.md)` statt `EdgeInsets.all(12)`.
/// Vorher: app-weit Mix aus 6/8/10/12/14 ohne Pattern → optisch unruhig.
class AppSpacing {
  const AppSpacing._();

  /// 4dp — minimal (Icon-Text-Abstand)
  static const double xxs = 4;

  /// 8dp — eng (kompakte Listen, kleine Gaps)
  static const double xs = 8;

  /// 12dp — Default für Card-Inhalte
  static const double sm = 12;

  /// 16dp — Standard Padding für Screens / Sections
  static const double md = 16;

  /// 20dp — größerer Section-Abstand
  static const double lg = 20;

  /// 24dp — Group-Trenner
  static const double xl = 24;

  /// 32dp — Hero / großer Abstand
  static const double xxl = 32;
}

/// Brand-Color-Hierarchie:
/// - **Bronze** (#c79363) = Markenidentität, Donor-Tier, Editorial-Akzente,
///   "Cinema-Feel". Nutze für CTAs die Brand-Identität ausdrücken sollen.
/// - **Amber** (#F59E0B) = Interactive-Primary. Active-State auf Tabs,
///   wichtige Toggle-Buttons, primärer "Send"-Button.
/// - **Teal** (#0EA5E9) = Smart-Match, Info, Sekundär-Akzent
/// - **Herzrot** (#EF4444) = Error, Destructive, Notfall, Live-Indikator
/// - **Leben** (#22C55E) = Erfolg, Online-Status, Help-Offered
///
/// Regel: PRO Action genau EINE der Farben. Niemals zwei "Primary"-Colors
/// in einem Screen mischen.
class AppColorRole {
  const AppColorRole._();
}
