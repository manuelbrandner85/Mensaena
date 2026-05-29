import 'package:flutter/material.dart';

/// SKILL: mensaena-design
/// CINEMA-HYPERREAL Palette (Claude-Design-Handoff 2026-05, "Mensaena
/// Cinematic App"). Wärmere, filmische Variante: Text als Papier-Creme
/// (#ECE5D6) statt kühlem Slate, gedämpftes Teal, warmes Korall-Rot,
/// Salbei-Grün. Bronze (#C79363) ist der Leit-Akzent.
/// Token-Namen unverändert → re-skinnt die gesamte App über die Werte.
class AppColors {
  const AppColors._();

  // ── Die Nacht (Basis-Flaechen, dunkel → hell) ─────────────────────
  // Design-Background #0A1018 (kühl-tiefes Navy), Flächen warm gestaffelt.
  static const Color voidColor = Color(0xFF0A1018);
  static const Color deep = Color(0xFF0E1626);
  static const Color surface = Color(0xFF141C2A);
  static const Color elevated = Color(0xFF1B2738);
  static const Color raised = Color(0xFF243246);
  static const Color overlay = Color(0xFF2D3D52);

  // ── Laternenlicht (Primaer-Akzent: warmes Amber) ──────────────────
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberWarm = Color(0xFFFBBF24);
  static const Color amberSoft = Color(0xFFFDE68A);
  static const Color amberDeep = Color(0xFF92400E);
  static const Color amberGlow = Color(0x4DF59E0B);

  // ── Abendluft (Sekundaer: gedämpftes Film-Teal) ───────────────────
  // Design-Brand-Teal #2B5663 (tief). Vordergrund-Varianten heller damit
  // Text/Icons auf dunklem Grund lesbar bleiben.
  static const Color teal = Color(0xFF4E7E8C);
  static const Color tealSoft = Color(0xFF9CC2CC);
  static const Color tealDeep = Color(0xFF2B5663);
  static const Color tealGlow = Color(0x4D4E7E8C);

  // ── Emotionen (warmes Korall-Rot statt grellem Rot) ───────────────
  static const Color herzrot = Color(0xFFE25C4A);
  static const Color herzrotWarm = Color(0xFFF0A498);
  static const Color herzrotDeep = Color(0xFF6E2A22);
  static const Color herzrotGlow = Color(0x40E25C4A);

  // ── Leben (gedämpftes Salbei-Grün) ────────────────────────────────
  static const Color leben = Color(0xFF5DC28A);
  static const Color lebenSoft = Color(0xFFA6E0BE);

  // ── Vertrauen (Trust-Sterne, Badges) ──────────────────────────────
  static const Color trust = Color(0xFFD4A054);
  static const Color trustSoft = Color(0xFFE8C88A);

  // ── Bronze (Leit-Akzent, Editorial) ───────────────────────────────
  static const Color bronze = Color(0xFFC79363);
  static const Color bronzeSoft = Color(0xFFE7C4A0);
  static const Color bronzeDeep = Color(0xFF8A5A2F);

  // ── Text (warmes Papier-Creme — der Design-Leitwert) ──────────────
  static const Color ink = Color(0xFFECE5D6);
  static const Color inkWarm = Color(0xFFFEF3C7);
  static const Color inkSoft = Color(0xFFCDC4B1);
  static const Color mute = Color(0xFF8B8576);
  static const Color ghost = Color(0xFF5E5A50);

  // ── Linien & Trenner (warmer Papier-Tint statt Weiß) ──────────────
  static const Color line = Color(0x1FECE5D6);
  static const Color lineActive = Color(0x4DC79363);

  // ════════════════════════════════════════════════════════════════
  // LIGHT-THEME PENDANTS (V20 Phase-6b)
  // Helle Counterparts fuer Dark/Light-Toggle. Bestehende
  // Dark-Konstanten bleiben unveraendert — diese sind ZUSAETZLICH.
  // ════════════════════════════════════════════════════════════════

  // ── Light Flaechen (Tag) ──────────────────────────────────────────
  static const Color lightVoid = Color(0xFFF5F5F0);     // App-Background (warmes Off-White)
  static const Color lightDeep = Color(0xFFEFEFE9);     // Canvas (leicht waermer)
  static const Color lightSurface = Color(0xFFFFFFFF);  // Card-Background
  static const Color lightElevated = Color(0xFFFAFAF5); // Input-Background
  static const Color lightRaised = Color(0xFFF0F0EB);   // Hover-Surface
  static const Color lightOverlay = Color(0xFFE8E8E2);  // Sehr leichte Overlay-Schicht

  // ── Light Text ────────────────────────────────────────────────────
  static const Color lightInk = Color(0xFF1A1A1A);      // Primaer-Text
  static const Color lightInkSoft = Color(0xFF3F3F46);  // Sekundaer-Text
  static const Color lightMute = Color(0xFF71717A);     // Muted/Hint
  static const Color lightGhost = Color(0xFFA1A1AA);    // Ghost/Placeholder

  // ── Light Linien & Trenner ────────────────────────────────────────
  static const Color lightLine = Color(0x14000000);     // 8% Black
  static const Color lightLineActive = Color(0x33D97706); // Amber-Tint fuer Active
}
