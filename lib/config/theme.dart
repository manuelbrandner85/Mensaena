import 'package:flutter/material.dart';

class AppColors {
  // Primary Teal
  static const Color primary50 = Color(0xFFd0f5f3);
  static const Color primary100 = Color(0xFFa8ede9);
  static const Color primary200 = Color(0xFF7ee3de);
  static const Color primary300 = Color(0xFF54d9d3);
  static const Color primary400 = Color(0xFF2acfc8);
  static const Color primary500 = Color(0xFF1EAAA6);
  static const Color primary600 = Color(0xFF198e8b);
  static const Color primary700 = Color(0xFF147170);
  static const Color primary800 = Color(0xFF0f5554);
  static const Color primary900 = Color(0xFF0a3939);

  // Primary Dark (green accent)
  static const Color primaryDark = Color(0xFF16a34a);

  // Warm Background
  static const Color warmBg = Color(0xFFf5f0eb);
  static const Color background = Color(0xFFEEF9F9);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FFFE);

  // Ink (Text)
  static const Color inkDark = Color(0xFF1a1a1a);
  static const Color inkMedium = Color(0xFF4a4a4a);
  static const Color inkLight = Color(0xFF9ca3af);

  // Legacy aliases
  static const Color textPrimary = inkDark;
  static const Color textSecondary = inkMedium;
  static const Color textMuted = inkLight;
  static const Color textOnPrimary = Colors.white;

  // Accent
  static const Color accent = Color(0xFF2563eb);

  // Trust Blue
  static const Color trust = Color(0xFF4F6D8A);
  static const Color trustLight = Color(0xFFE8EEF4);

  // Emergency Red
  static const Color emergency = Color(0xFFC62828);
  static const Color emergencyLight = Color(0xFFFDE8E8);

  // Error / Warning / Success / Info
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF059669);
  static const Color info = Color(0xFF3B82F6);

  // Border
  static const Color border = Color(0xFFe7e5e4);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Category Colors
  static const Color categoryHelp = Color(0xFF1EAAA6);
  static const Color categoryAnimal = Color(0xFF8B5CF6);
  static const Color categoryHousing = Color(0xFF3B82F6);
  static const Color categoryMobility = Color(0xFF06B6D4);
  static const Color categorySharing = Color(0xFFF59E0B);
  static const Color categoryCrisis = Color(0xFFC62828);
  static const Color categoryCommunity = Color(0xFF10B981);
}

class AppTextStyles {
  static const TextStyle metaLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.inkLight,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: AppColors.inkDark,
    height: 1.2,
  );

  static const TextStyle pageSubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.inkLight,
    height: 1.4,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        primary: AppColors.primary500,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.trust,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.warmBg,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary500,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary500,
          side: const BorderSide(color: AppColors.primary500),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary500,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary500, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary50,
        selectedColor: AppColors.primary500,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 0),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
    );
  }
}

class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 15, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> glow = [
    BoxShadow(color: AppColors.primary500.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 4)),
  ];
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
