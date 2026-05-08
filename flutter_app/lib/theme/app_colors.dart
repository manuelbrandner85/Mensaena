import 'package:flutter/material.dart';

/// Farbpalette – 1:1 übernommen aus tailwind.config.ts der Web-App.
/// Quelle: /tailwind.config.ts (theme.extend.colors)
class AppColors {
  AppColors._();

  // Primary (Teal-Green) – identisch zur Web-App
  static const primary50 = Color(0xFFEFFCFB);
  static const primary100 = Color(0xFFD0F5F3);
  static const primary200 = Color(0xFFA3EAE8);
  static const primary300 = Color(0xFF6DDAD7);
  static const primary400 = Color(0xFF38C4C0);
  static const primary500 = Color(0xFF1EAAA6); // Hauptfarbe
  static const primary600 = Color(0xFF178D8A);
  static const primary700 = Color(0xFF147170); // Dark
  static const primary800 = Color(0xFF135A59);
  static const primary900 = Color(0xFF144B4A);

  // Trust (Blau-Grau) – Vertrauen / Sekundär-Akzent
  static const trust50 = Color(0xFFEFF4FA);
  static const trust100 = Color(0xFFD6E4F0);
  static const trust200 = Color(0xFFADC8E1);
  static const trust300 = Color(0xFF7FA8CC);
  static const trust400 = Color(0xFF4F6D8A);
  static const trust500 = Color(0xFF3D5A73);
  static const trust600 = Color(0xFF2C4157);

  // Warm (Light teal-tinted neutrals)
  static const warm50 = Color(0xFFF4FEFE);
  static const warm100 = Color(0xFFE6F9F9);
  static const warm200 = Color(0xFFCCF1F0);
  static const warm300 = Color(0xFFA8E5E4);

  // Ink (Editorial near-black) – Haupt-Textfarbe
  static const ink50 = Color(0xFFF4F6F6);
  static const ink100 = Color(0xFFDEE4E3);
  static const ink200 = Color(0xFFB9C3C2);
  static const ink300 = Color(0xFF8D9B99);
  static const ink400 = Color(0xFF5E7270);
  static const ink500 = Color(0xFF3B4F4D);
  static const ink600 = Color(0xFF243634);
  static const ink700 = Color(0xFF162321);
  static const ink800 = Color(0xFF0E1A19);
  static const ink900 = Color(0xFF0B1514);

  // Stone (warme Neutrals)
  static const stone50 = Color(0xFFFAFAF7);
  static const stone100 = Color(0xFFF2F2EC);
  static const stone200 = Color(0xFFE4E4DB);
  static const stone300 = Color(0xFFCFCFC2);
  static const stone400 = Color(0xFF9C9C8E);
  static const stone500 = Color(0xFF6E6E62);
  static const stone600 = Color(0xFF4B4B42);
  static const stone700 = Color(0xFF33332C);
  static const stone800 = Color(0xFF1F1F1A);
  static const stone900 = Color(0xFF111110);

  // Emergency (für Krisen-Module / Notruf)
  static const emergency500 = Color(0xFFC62828);
  static const emergency600 = Color(0xFFB71C1C);

  // Spezial-Hintergründe
  static const background = Color(0xFFEEF9F9); // App-Background
  static const paper = Color(0xFFFAFAF7); // Card-Background

  // Gray (für Fallbacks)
  static const gray400 = Color(0xFF9CA3AF);
  static const gray700 = Color(0xFF374151);
  static const gray900 = Color(0xFF111827);

  // MaterialColor-Wrapper für ColorScheme
  static MaterialColor primarySwatch = const MaterialColor(0xFF1EAAA6, {
    50: primary50,
    100: primary100,
    200: primary200,
    300: primary300,
    400: primary400,
    500: primary500,
    600: primary600,
    700: primary700,
    800: primary800,
    900: primary900,
  });
}
