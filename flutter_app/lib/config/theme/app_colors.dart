import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// Cinema-Dark Palette — matched zur Live-Webseite www.mensaena.de
/// (PRs #571-#573 globals.css). Brief-Style-Spec mit Teal #1EAAA6 ist
/// veraltet; wir folgen der Live-Web-Reality.
class AppColors {
  const AppColors._();

  // ── Die Nacht (Basis-Flaechen, dunkel → hell) ─────────────────────
  static const Color voidColor = Color(0xFF0A0F1C);
  static const Color deep = Color(0xFF0F1628);
  static const Color surface = Color(0xFF162035);
  static const Color elevated = Color(0xFF1C2A42);
  static const Color raised = Color(0xFF243350);
  static const Color overlay = Color(0xFF2B3D5E);

  // ── Laternenlicht (Primaer-Akzent: warmes Amber) ──────────────────
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberWarm = Color(0xFFFBBF24);
  static const Color amberSoft = Color(0xFFFDE68A);
  static const Color amberDeep = Color(0xFF92400E);
  static const Color amberGlow = Color(0x4DF59E0B);

  // ── Abendluft (Sekundaer: kuehles Blau) ───────────────────────────
  static const Color teal = Color(0xFF0EA5E9);
  static const Color tealSoft = Color(0xFF7DD3FC);
  static const Color tealDeep = Color(0xFF075985);
  static const Color tealGlow = Color(0x4D0EA5E9);

  // ── Emotionen ─────────────────────────────────────────────────────
  static const Color herzrot = Color(0xFFEF4444);
  static const Color herzrotWarm = Color(0xFFF87171);
  static const Color herzrotDeep = Color(0xFF7F1D1D);
  static const Color herzrotGlow = Color(0x40EF4444);

  static const Color leben = Color(0xFF22C55E);
  static const Color lebenSoft = Color(0xFF86EFAC);

  // ── Vertrauen (Trust-Sterne, Badges) ──────────────────────────────
  static const Color trust = Color(0xFFD4A054);
  static const Color trustSoft = Color(0xFFE8C88A);

  // ── Bronze (Donor-Tier, Editorial) ────────────────────────────────
  static const Color bronze = Color(0xFFC79363);
  static const Color bronzeSoft = Color(0xFFE7C4A0);
  static const Color bronzeDeep = Color(0xFF7C4A1F);

  // ── Text ──────────────────────────────────────────────────────────
  static const Color ink = Color(0xFFF1F5F9);
  static const Color inkWarm = Color(0xFFFEF3C7);
  static const Color inkSoft = Color(0xFFCBD5E1);
  static const Color mute = Color(0xFF64748B);
  static const Color ghost = Color(0xFF475569);

  // ── Linien & Trenner ──────────────────────────────────────────────
  static const Color line = Color(0x12FFFFFF);
  static const Color lineActive = Color(0x33F59E0B);
}
