import 'package:flutter/material.dart';
import 'colors.dart';

/// Cinematic Shadow-Praesets. Jedes Praeset hat einen "Glow"-Layer
/// (grosser Blur, niedrige Opazitaet) plus einen kompakten Drop-Shadow.
class MnShadows {
  const MnShadows._();

  // ── Laternen-Glow um interaktive Primary-Elemente ─────────────────────
  static const List<BoxShadow> amberGlow = [
    BoxShadow(color: Color(0x66F59E0B), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x26F59E0B), blurRadius: 40),
  ];

  // ── Karten-Schatten (Default) ─────────────────────────────────────────
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
  ];

  // ── Karten-Schatten (Hover/Active) mit warmem Touch ───────────────────
  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x14F59E0B), blurRadius: 30),
  ];

  // ── Modal- und Sheet-Schatten (sehr tief) ─────────────────────────────
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x99000000), blurRadius: 48, offset: Offset(0, 16)),
  ];

  // ── Krisenmodus / Herzrot-Akzente ─────────────────────────────────────
  static const List<BoxShadow> herzrotGlow = [
    BoxShadow(color: Color(0x66EF4444), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x26EF4444), blurRadius: 40),
  ];

  // ── Teal-Akzente (Sekundaer-Buttons, Online-Status) ───────────────────
  static const List<BoxShadow> tealGlow = [
    BoxShadow(color: Color(0x4D0EA5E9), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A0EA5E9), blurRadius: 30),
  ];

  // ── Input-Focus (subtiler Amber-Ring) ─────────────────────────────────
  static const List<BoxShadow> inputFocus = [
    BoxShadow(color: Color(0x33F59E0B), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// Glow-Praesets je Akzent-Farbe (z.B. Module-Header).
  static List<BoxShadow> coloredGlow(Color color, {double opacity = 0.30}) {
    final hot = color.withValues(alpha: 0.40);
    final soft = color.withValues(alpha: opacity * 0.4);
    return [
      BoxShadow(color: hot, blurRadius: 16, offset: const Offset(0, 4)),
      BoxShadow(color: soft, blurRadius: 40),
    ];
  }

  /// Inset-Highlight am oberen Karten-Rand (innerer 1px Strich).
  static const BoxDecoration cardInnerHighlight = BoxDecoration(
    border: Border(
      top: BorderSide(color: Color(0x0AFFFFFF), width: 1),
    ),
  );
}
