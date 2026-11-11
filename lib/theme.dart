import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0d1220);
  static const card = Color(0xFF1a2238);
  static const ink = Color(0xFFf3efe4);
  static const muted = Color(0xFF8a9ab8);
  static const gold = Color(0xFFe6b65c);
  static const teal = Color(0xFF4fb7a8);
  static const danger = Color(0xFFe0705f);
  static const divider = Color(0xFF263048);
}

class AppTheme {
  static const _arabic = 'sans-serif';

  static ThemeData get theme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.teal,
        surface: AppColors.card,
        error: AppColors.danger,
        onPrimary: AppColors.bg,
        onSecondary: AppColors.bg,
        onSurface: AppColors.ink,
        onError: AppColors.ink,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        displayMedium: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        displaySmall: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        headlineLarge: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        headlineMedium: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        headlineSmall: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        titleLarge: TextStyle(fontFamily: _arabic, color: AppColors.ink, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        titleSmall: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        bodyLarge: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        bodyMedium: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        bodySmall: TextStyle(fontFamily: _arabic, color: AppColors.muted),
        labelLarge: TextStyle(fontFamily: _arabic, color: AppColors.ink),
        labelMedium: TextStyle(fontFamily: _arabic, color: AppColors.muted),
        labelSmall: TextStyle(fontFamily: _arabic, color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerColor: AppColors.divider,
      iconTheme: const IconThemeData(color: AppColors.muted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.gold.withAlpha(26),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: const TextStyle(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
