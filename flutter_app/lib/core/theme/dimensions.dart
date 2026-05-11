/// Spacing- und Radius-Skala fuer das Cinema-Design-System.
class MnDimensions {
  const MnDimensions._();

  // ── Radius ────────────────────────────────────────────────────────────
  static const double radiusCard   = 20;
  static const double radiusButton = 14;
  static const double radiusInput  = 12;
  static const double radiusModal  = 24;
  static const double radiusPill   = 100;

  // ── Spacing (4-er Skala) ──────────────────────────────────────────────
  static const double spaceXs  = 4;
  static const double spaceSm  = 8;
  static const double spaceMd  = 16;
  static const double spaceLg  = 24;
  static const double spaceXl  = 32;
  static const double spaceXxl = 48;

  // ── Icon-Groessen ─────────────────────────────────────────────────────
  static const double iconSm  = 16;
  static const double iconMd  = 20;
  static const double iconLg  = 24;
  static const double iconXl  = 36;
  static const double iconXxl = 48;

  // ── Avatar-Groessen ───────────────────────────────────────────────────
  static const double avatarXs = 24;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 80;

  // ── Animation-Dauer (cinematic, nicht hektisch) ───────────────────────
  static const Duration durFast   = Duration(milliseconds: 150);
  static const Duration durMed    = Duration(milliseconds: 250);
  static const Duration durSlow   = Duration(milliseconds: 400);
  static const Duration durScene  = Duration(milliseconds: 800);
}
