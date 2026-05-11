import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'dimensions.dart';
import 'typography.dart';

/// Globale ThemeData fuer Cinema 3.0. Dark-First, Material 3, mit
/// Cinema-Tokens als Defaults. Komponenten verwenden trotzdem die
/// expliziten MnColors / MnShadows fuer feinere Kontrolle.
class MensaenaTheme {
  const MensaenaTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: MnColors.voidColor,
      canvasColor: MnColors.deep,

      colorScheme: const ColorScheme.dark(
        primary: MnColors.amber,
        onPrimary: MnColors.voidColor,
        secondary: MnColors.teal,
        onSecondary: MnColors.voidColor,
        tertiary: MnColors.trust,
        surface: MnColors.surface,
        onSurface: MnColors.ink,
        surfaceContainerHighest: MnColors.elevated,
        error: MnColors.herzrot,
        onError: MnColors.ink,
        outline: MnColors.line,
      ),

      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: MnColors.ink,
        displayColor: MnColors.ink,
      ),

      iconTheme: const IconThemeData(color: MnColors.inkSoft, size: MnDimensions.iconLg),

      dividerTheme: const DividerThemeData(
        color: MnColors.line,
        thickness: 1,
        space: 1,
      ),

      splashFactory: InkRipple.splashFactory,
      splashColor: MnColors.amberGlow,
      highlightColor: const Color(0x14F59E0B),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: MnTypography.appBarTitle(),
        iconTheme: const IconThemeData(color: MnColors.inkSoft, size: MnDimensions.iconLg),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: MnColors.amber,
        unselectedItemColor: MnColors.mute,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: MnColors.amber,
        unselectedLabelColor: MnColors.mute,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: MnColors.amber, width: 2),
        ),
        labelStyle: MnTypography.body(size: 14, weight: FontWeight.w600, color: MnColors.amber),
        unselectedLabelStyle: MnTypography.body(size: 14, weight: FontWeight.w500),
        dividerColor: MnColors.line,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: MnColors.elevated,
        contentTextStyle: MnTypography.body(color: MnColors.ink),
        actionTextColor: MnColors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        ),
      ),
    );
  }
}
