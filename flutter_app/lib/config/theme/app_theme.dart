import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// SKILL: mensaena-design
/// Material-3-Theme mit Cinema-Dark Tokens. Root in app.dart.
class AppTheme {
  const AppTheme._();

  /// Light-Theme (V20 Phase-6b) — helles Pendant zum Cinema-Dark.
  /// Brand-Akzente (Amber, Bronze, Teal, Herzrot) bleiben gleich,
  /// nur Flaechen + Text invertieren.
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.amber,
      onPrimary: Colors.white,
      primaryContainer: AppColors.amberSoft,
      onPrimaryContainer: AppColors.amberDeep,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.tealSoft,
      onSecondaryContainer: AppColors.tealDeep,
      tertiary: AppColors.bronze,
      onTertiary: Colors.white,
      error: AppColors.herzrot,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      surfaceContainer: AppColors.lightElevated,
      surfaceContainerHigh: AppColors.lightRaised,
      surfaceContainerHighest: AppColors.lightOverlay,
      outline: AppColors.lightLine,
      outlineVariant: AppColors.lightLineActive,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightVoid,
      canvasColor: AppColors.lightDeep,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightLine),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.body(
            size: 15,
            color: Colors.white,
            weight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amberDeep,
          side: BorderSide(color: AppColors.amber.withValues(alpha: 0.55), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.amberDeep,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.body(size: 14, color: AppColors.lightMute),
        labelStyle: AppTypography.label(size: 11, color: AppColors.lightInkSoft),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.amber, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.herzrot),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.herzrot, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightLine,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightElevated,
        labelStyle: AppTypography.label(size: 11, color: AppColors.amberDeep),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: const BorderSide(color: AppColors.lightLine),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightInk,
        contentTextStyle:
            AppTypography.body(size: 14, color: AppColors.lightVoid),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CinematicFadeTransitionBuilder(),
          TargetPlatform.iOS: _CinematicFadeTransitionBuilder(),
          TargetPlatform.linux: _CinematicFadeTransitionBuilder(),
          TargetPlatform.macOS: _CinematicFadeTransitionBuilder(),
          TargetPlatform.windows: _CinematicFadeTransitionBuilder(),
          TargetPlatform.fuchsia: _CinematicFadeTransitionBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.amber,
      onPrimary: AppColors.voidColor,
      primaryContainer: AppColors.amberDeep,
      onPrimaryContainer: AppColors.amberSoft,
      secondary: AppColors.teal,
      onSecondary: AppColors.voidColor,
      secondaryContainer: AppColors.tealDeep,
      onSecondaryContainer: AppColors.tealSoft,
      tertiary: AppColors.bronze,
      onTertiary: AppColors.voidColor,
      error: AppColors.herzrot,
      onError: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainer: AppColors.elevated,
      surfaceContainerHigh: AppColors.raised,
      surfaceContainerHighest: AppColors.overlay,
      outline: AppColors.line,
      outlineVariant: AppColors.lineActive,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.voidColor,
      canvasColor: AppColors.deep,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      // Design (Cinema-Hyperreal): alle Bottom-Sheets bekommen zentral den
      // dunklen Glass-Strong-Ton + rounded-22-Oberkante. Sheets die ihren
      // eigenen Container malen überschreiben das ggf. weiterhin.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF0121A28),
        modalBackgroundColor: Color(0xF0121A28),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: Color(0x33ECE5D6)),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.voidColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.body(
            size: 15,
            color: AppColors.voidColor,
            weight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          side: const BorderSide(color: AppColors.lineActive, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.deep.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.body(size: 14, color: AppColors.mute),
        labelStyle: AppTypography.label(size: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.amber, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.herzrot),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.herzrot, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.5),
        labelStyle: AppTypography.label(size: 11, color: AppColors.amber),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: const BorderSide(color: AppColors.line),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: AppTypography.body(size: 14, color: AppColors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
      ),
      // Cinematic Page-Transitions: Fade-Through-Black auf allen Plattformen.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CinematicFadeTransitionBuilder(),
          TargetPlatform.iOS: _CinematicFadeTransitionBuilder(),
          TargetPlatform.linux: _CinematicFadeTransitionBuilder(),
          TargetPlatform.macOS: _CinematicFadeTransitionBuilder(),
          TargetPlatform.windows: _CinematicFadeTransitionBuilder(),
          TargetPlatform.fuchsia: _CinematicFadeTransitionBuilder(),
        },
      ),
    );
  }
}

/// Fade-Through-Black: 180 ms fade-out → 180 ms fade-in. Wie Kino-Schnitt.
class _CinematicFadeTransitionBuilder extends PageTransitionsBuilder {
  const _CinematicFadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    final scale = Tween<double>(begin: 1.02, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final secondary = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    return Stack(
      children: [
        // Black-fade-through (only during 0-50% of forward animation)
        FadeTransition(
          opacity: secondary,
          child: const ColoredBox(color: Colors.black),
        ),
        FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        ),
      ],
    );
  }
}
