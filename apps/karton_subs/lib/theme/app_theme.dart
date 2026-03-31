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

// ── Semantic Color Tokens ─────────────────────────────────────────────────
/// Theme-aware semantic colors resolved via [ThemeExtension].
/// Widgets use `Theme.of(context).extension<AppSemanticColors>()!` or the
/// `context.semanticColors` shorthand — zero `isDark` checks needed.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color positive;
  final Color positiveBg;
  final Color negative;
  final Color negativeBg;
  final Color warning;
  final Color warningBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color heroCardBg;
  final Color heroCardText;
  final Color heroCardTextSecondary;

  const AppSemanticColors({
    required this.positive,
    required this.positiveBg,
    required this.negative,
    required this.negativeBg,
    required this.warning,
    required this.warningBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.heroCardBg,
    required this.heroCardText,
    required this.heroCardTextSecondary,
  });

  // ── Light ────────────────────────────────────────────────────────────────
  static const light = AppSemanticColors(
    positive: AppColors.positive,
    positiveBg: AppColors.positiveBg,
    negative: AppColors.negative,
    negativeBg: AppColors.negativeBg,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceVariant,
    primary: AppColors.lightPrimary,
    heroCardBg: AppColors.lightPrimary,
    heroCardText: Colors.white,
    heroCardTextSecondary: Colors.white70,
  );

  // ── Dark — status foreground brightened (400 vs 600) for contrast ───────
  static final dark = AppSemanticColors(
    positive: const Color(0xFF4ADE80),   // Green-400
    positiveBg: const Color(0xFF4ADE80).withValues(alpha: 0.10),
    negative: const Color(0xFFF87171),   // Red-400
    negativeBg: const Color(0xFFF87171).withValues(alpha: 0.10),
    warning: const Color(0xFFFBBF24),    // Amber-400
    warningBg: const Color(0xFFFBBF24).withValues(alpha: 0.10),
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    border: AppColors.darkBorder,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceVariant,
    primary: AppColors.darkPrimary,
    heroCardBg: AppColors.darkPrimary.withValues(alpha: 0.15),
    heroCardText: AppColors.darkTextPrimary,
    heroCardTextSecondary: AppColors.darkTextSecondary,
  );

  @override
  AppSemanticColors copyWith({
    Color? positive,
    Color? positiveBg,
    Color? negative,
    Color? negativeBg,
    Color? warning,
    Color? warningBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? surface,
    Color? surfaceVariant,
    Color? primary,
    Color? heroCardBg,
    Color? heroCardText,
    Color? heroCardTextSecondary,
  }) {
    return AppSemanticColors(
      positive: positive ?? this.positive,
      positiveBg: positiveBg ?? this.positiveBg,
      negative: negative ?? this.negative,
      negativeBg: negativeBg ?? this.negativeBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      primary: primary ?? this.primary,
      heroCardBg: heroCardBg ?? this.heroCardBg,
      heroCardText: heroCardText ?? this.heroCardText,
      heroCardTextSecondary: heroCardTextSecondary ?? this.heroCardTextSecondary,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      positive: Color.lerp(positive, other.positive, t)!,
      positiveBg: Color.lerp(positiveBg, other.positiveBg, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeBg: Color.lerp(negativeBg, other.negativeBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      heroCardBg: Color.lerp(heroCardBg, other.heroCardBg, t)!,
      heroCardText: Color.lerp(heroCardText, other.heroCardText, t)!,
      heroCardTextSecondary: Color.lerp(heroCardTextSecondary, other.heroCardTextSecondary, t)!,
    );
  }
}

/// Shorthand: `context.semanticColors`
extension SemanticColorsExtension on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
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

      // Semantic color extension
      extensions: [isDark ? AppSemanticColors.dark : AppSemanticColors.light],

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
