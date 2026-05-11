import 'package:flutter/material.dart';

/// Mensaena Cinema 3.0 — "Die lebendige Nachbarschaft bei Nacht".
///
/// Goldenes Laternenlicht, blauschwarze Nacht, warme Akzente. Keine Sci-Fi-
/// Farben, kein Neon. Jeder Wert hat einen erzaehlerischen Zweck.
class MnColors {
  const MnColors._();

  // ── Die Nacht (Basis-Flaechen, dunkel nach hell) ──────────────────────
  static const Color voidColor = Color(0xFF0A0F1C);
  static const Color deep      = Color(0xFF0F1628);
  static const Color surface   = Color(0xFF162035);
  static const Color elevated  = Color(0xFF1C2A42);
  static const Color raised    = Color(0xFF243350);
  static const Color overlay   = Color(0xFF2B3D5E);

  // ── Laternenlicht (Primaer-Akzent: warmes Amber) ──────────────────────
  static const Color amber     = Color(0xFFF59E0B);
  static const Color amberWarm = Color(0xFFFBBF24);
  static const Color amberSoft = Color(0xFFFDE68A);
  static const Color amberDeep = Color(0xFF92400E);
  static const Color amberGlow = Color(0x4DF59E0B); // 30% Amber fuer Shadows

  // ── Abendluft (Sekundaer: kuehles Blau) ───────────────────────────────
  static const Color teal      = Color(0xFF0EA5E9);
  static const Color tealSoft  = Color(0xFF7DD3FC);
  static const Color tealDeep  = Color(0xFF075985);

  // ── Emotionen ─────────────────────────────────────────────────────────
  static const Color herzrot     = Color(0xFFEF4444);
  static const Color herzrotWarm = Color(0xFFF87171);
  static const Color herzrotDeep = Color(0xFF7F1D1D);
  static const Color herzrotGlow = Color(0x40EF4444); // 25%

  static const Color leben     = Color(0xFF22C55E);
  static const Color lebenSoft = Color(0xFF86EFAC);

  // ── Vertrauen (Trust-Sterne, Badges) ──────────────────────────────────
  static const Color trust     = Color(0xFFD4A054);
  static const Color trustSoft = Color(0xFFE8C88A);

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color ink     = Color(0xFFF1F5F9);
  static const Color inkWarm = Color(0xFFFEF3C7);
  static const Color inkSoft = Color(0xFFCBD5E1);
  static const Color mute    = Color(0xFF64748B);
  static const Color ghost   = Color(0xFF475569);

  // ── Linien & Trenner ──────────────────────────────────────────────────
  static const Color line       = Color(0x12FFFFFF); // 7% Weiss
  static const Color lineActive = Color(0x33F59E0B); // 20% Amber
}
