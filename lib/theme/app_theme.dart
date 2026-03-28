// app_theme.dart v0.001 Ledger Glass design system — flat M3, zero cieni

import 'dart:ui';
import 'package:flutter/material.dart';

/// Paleta kolorów "Ledger Glass"
class AppColors {
  AppColors._();

  // ==================== LIGHT MODE: "Clean Ledger" ====================
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1B2A4A); // Deep Navy
  static const Color lightSecondary = Color(0xFF3D6B9E); // Steel Blue
  static const Color lightAccent = Color(0xFF2563EB); // Bright Blue
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ==================== DARK MODE: "Midnight Terminal" ====================
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkPrimary = Color(0xFF93C5FD); // Light Blue
  static const Color darkAccent = Color(0xFF3B82F6);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);

  // ==================== SEMANTIC COLORS ====================
  static const Color positive = Color(0xFF16A34A); // Green — savings
  static const Color negative = Color(0xFFDC2626); // Red — overspend
  static const Color warning = Color(0xFFD97706); // Amber — warning

  // ==================== CHART COLORS ====================
  static const List<Color> chartColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Violet
    Color(0xFF0891B2), // Cyan
    Color(0xFFEA580C), // Orange
    Color(0xFF16A34A), // Green
    Color(0xFFDB2777), // Pink
    Color(0xFFD97706), // Amber
    Color(0xFF64748B), // Slate
  ];
}

/// Geometria komponentów
class AppGeometry {
  AppGeometry._();

  // Border radius
  static const double radiusCard = 12.0;
  static const double radiusChip = 8.0;
  static const double radiusButton = 12.0;
  static const double radiusInput = 8.0;

  // Spacing (8px grid)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingBase = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
}

/// Theme builder — Ledger Glass
class AppTheme {
  AppTheme._();

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightSecondary,
        surface: AppColors.lightSurface,
        error: AppColors.negative,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
      ),
      textTheme: _buildTextTheme(AppColors.lightTextPrimary),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        color: AppColors.lightSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
          ),
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
          ),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          borderSide:
              const BorderSide(color: AppColors.lightAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGeometry.spacingBase,
          vertical: AppGeometry.spacingMd,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusChip),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.lightAccent.withValues(alpha: 0.12),
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.lightBorder,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        error: AppColors.negative,
        onPrimary: AppColors.darkBackground,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
      ),
      textTheme: _buildTextTheme(AppColors.darkTextPrimary),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        color: AppColors.darkSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
          ),
          backgroundColor: AppColors.darkAccent,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
          ),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGeometry.spacingBase,
          vertical: AppGeometry.spacingMd,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusChip),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.darkAccent.withValues(alpha: 0.24),
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ==================== TYPOGRAPHY ====================
  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      // Display Large (32px, 700): Główny koszt miesięczny
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Headline Medium (20px, 600): Tytuły sekcji
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Title Medium (16px, 600): Nazwy subskrypcji
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Body Medium (14px, 400): Opisy
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Body Large (16px, 400): Większy tekst body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Label Medium (12px, 500): Chipy, metadane
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Label Small (11px, 400): Etykiety wykresów
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
    );
  }
}
