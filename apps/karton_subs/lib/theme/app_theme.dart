import 'package:flutter/material.dart';

/// Ledger Glass — design system wg docs/design.md.
/// Bloomberg Terminal meets Material Design 3.
/// Zero neumorfizmu, zero custom widgetów na poziomie design systemu.
class AppColors {
  AppColors._();

  // ── Light Mode: "Clean Ledger" ──────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightPrimary = Color(0xFF1E3A5F); // Deep Navy
  static const Color lightSecondary = Color(0xFF475569); // Slate-600
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate-900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate-500
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate-400

  static const Color positive = Color(0xFF16A34A); // Green-600
  static const Color positiveBg = Color(0xFFF0FDF4);
  static const Color negative = Color(0xFFDC2626); // Red-600
  static const Color negativeBg = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFD97706); // Amber-600
  static const Color warningBg = Color(0xFFFFFBEB);

  // ── Dark Mode: "Midnight Terminal" ─────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F172A); // Slate-900
  static const Color darkSurface = Color(0xFF1E293B); // Slate-800
  static const Color darkSurfaceVariant = Color(0xFF334155); // Slate-700
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkPrimary = Color(0xFF93C5FD); // Blue-300
  static const Color darkSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Slate-100
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: isDark ? AppColors.darkBackground : Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
      onPrimaryContainer: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      secondary: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
      onSecondary: isDark ? AppColors.darkBackground : Colors.white,
      secondaryContainer: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      onSecondaryContainer: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      error: AppColors.negative,
      onError: Colors.white,
      errorContainer: AppColors.negativeBg,
      onErrorContainer: AppColors.negative,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      outline: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      surfaceContainerHighest: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      surfaceContainerHigh: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      surfaceContainer: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,

      // Typography — tabular figures dla kwot finansowych
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      // Cards: outlined, elevation 0, 12px radius
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        margin: EdgeInsets.zero,
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // TextField: 8px radius
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: isDark
            ? AppColors.darkPrimary.withValues(alpha: 0.15)
            : AppColors.lightPrimary.withValues(alpha: 0.1),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
