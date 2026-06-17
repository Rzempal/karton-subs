import 'package:flutter/material.dart';

/// Aurora — design system wg docs/design.md (ADR-005).
/// Jeden uniwersalny ciemny motyw: gradient aurora w tle, powierzchnie „frost"
/// (półprzezroczystość bez rozmycia), akcent fiolet→cyan. Zero wariantu light.
class AppColors {
  AppColors._();

  // ── Tło ─────────────────────────────────────────────────────────────────
  static const Color bgSolid = Color(0xFF0E0A1F); // fallback / ekrany bez gradientu
  // Nieprzezroczysta powierzchnia „uniesiona" dla dialogów i bottom sheetów —
  // jaśniejsza od tła, by panel nie zlewał się z przyciemnionym obszarem.
  static const Color surfaceElevated = Color(0xFF231C49);
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241B4B), Color(0xFF16113A), Color(0xFF0B0822)],
    stops: [0.0, 0.52, 1.0],
  );
  static final Color glowViolet = const Color(0xFF7C5CFF).withValues(alpha: 0.45);
  static final Color glowCyan = const Color(0xFF22D3EE).withValues(alpha: 0.25);

  // ── Frost (powierzchnie — przezroczystość, BEZ BackdropFilter) ────────────
  static final Color frost1 = Colors.white.withValues(alpha: 0.07); // karty
  static final Color frost2 = Colors.white.withValues(alpha: 0.10); // kafle zagnieżdżone, chipy
  static final Color frostBorder = Colors.white.withValues(alpha: 0.14);
  static final Color frostBorderStrong = Colors.white.withValues(alpha: 0.20); // focus/aktywne
  static final Color navGlass = Colors.white.withValues(alpha: 0.10); // jedyne prawdziwe szkło

  // ── Akcenty ──────────────────────────────────────────────────────────────
  static const Color accentViolet = Color(0xFFA78BFA); // główny akcent (ikony, aktywne)
  static const Color accentCyan = Color(0xFF5EEAD4); // drugorzędny
  static const Color accentSolid = Color(0xFF8B7BF7); // gdy gradient niewskazany
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFC4B5FD), Color(0xFF5EEAD4)],
  );
  // Tekst/ikona na jasnym akcencie (gradient/pigułka aktywna) — kontrast WCAG OK.
  static const Color onAccent = Color(0xFF1B1240);

  // ── Tekst ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF3F0FF);
  static const Color textSecondary = Color(0xFFC2B9EC);
  static const Color textMuted = Color(0xFFA99FD0);

  // ── Semantyczne (foreground — shade 400 na ciemnym; tło @ 14% alpha) ──────
  static const Color positive = Color(0xFF34D399);
  static const Color negative = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color trial = Color(0xFF60A5FA);

  // ── Wykresy ──────────────────────────────────────────────────────────────
  static const List<Color> chartColors = [
    Color(0xFFA78BFA), Color(0xFF5EEAD4), Color(0xFF60A5FA),
    Color(0xFFFB923C), Color(0xFF34D399), Color(0xFFF472B6),
  ];
  static final Color barIdle = Colors.white.withValues(alpha: 0.12);
  static const LinearGradient barHighlight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFA78BFA), Color(0xFF5EEAD4)],
  );
}

/// Promienie zaokrągleń (geometria marki Aurora) — jedno źródło prawdy.
/// Nie zaszywaj liczb w widgetach; używaj tych tokenów.
class AppRadii {
  AppRadii._();

  static const double card = 22; // karty standardowe, dialogi, bottom sheety
  static const double metric = 18; // kafle metryk, karty strumienia
  static const double tile = 16; // wiersze list, chipy, grupy ustawień
  static const double pill = 30; // pasek nawigacji (pełna pigułka)
  static const double pillAction = 26; // pigułki akcji menu „Dodaj"
  static const double control = 12; // pola tekstowe, segment przełącznika
}

// ── Semantic Color Tokens ─────────────────────────────────────────────────
/// Theme-aware semantic colors resolved via [ThemeExtension].
/// Aurora ma JEDEN zestaw wartości (brak wariantu light) — mechanizm dostępu
/// `context.semanticColors` pozostaje bez zmian (ADR-002 / ADR-005).
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
  final Color trial;
  final Color trialBg;

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
    required this.trial,
    required this.trialBg,
  });

  // ── Aurora (jedyny zestaw) ─────────────────────────────────────────────────
  static final aurora = AppSemanticColors(
    positive: AppColors.positive,
    positiveBg: AppColors.positive.withValues(alpha: 0.14),
    negative: AppColors.negative,
    negativeBg: AppColors.negative.withValues(alpha: 0.14),
    warning: AppColors.warning,
    warningBg: AppColors.warning.withValues(alpha: 0.14),
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.frostBorder,
    surface: AppColors.frost1,
    surfaceVariant: AppColors.frost2,
    primary: AppColors.accentViolet,
    heroCardBg: AppColors.frost1,
    heroCardText: AppColors.textPrimary,
    heroCardTextSecondary: AppColors.textSecondary,
    trial: AppColors.trial,
    trialBg: AppColors.trial.withValues(alpha: 0.14),
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
    Color? trial,
    Color? trialBg,
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
      trial: trial ?? this.trial,
      trialBg: trialBg ?? this.trialBg,
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
      trial: Color.lerp(trial, other.trial, t)!,
      trialBg: Color.lerp(trialBg, other.trialBg, t)!,
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

  /// Jedyny motyw aplikacji (Aurora, ciemny).
  static ThemeData get theme => _build();

  // Aliasy zgodności — usuwane w Checkpoint 2 wraz z ThemeProvider.
  // Oba zwracają ten sam motyw Aurora, więc apka jest ciemna niezależnie od
  // ustawienia systemowego jeszcze przed wyczyszczeniem main.dart.
  static ThemeData get light => _build();
  static ThemeData get dark => _build();

  static ThemeData _build() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accentViolet,
      onPrimary: AppColors.bgSolid,
      primaryContainer: AppColors.accentSolid,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.accentCyan,
      onSecondary: AppColors.bgSolid,
      secondaryContainer: AppColors.frost2,
      onSecondaryContainer: AppColors.textPrimary,
      error: AppColors.negative,
      onError: AppColors.bgSolid,
      errorContainer: AppColors.negative.withValues(alpha: 0.14),
      onErrorContainer: AppColors.negative,
      surface: AppColors.bgSolid,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.frostBorder,
      outlineVariant: AppColors.frostBorder,
      surfaceContainerHighest: AppColors.frost2,
      surfaceContainerHigh: AppColors.frost2,
      surfaceContainer: AppColors.frost1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // Ekrany jeszcze nie owinięte w AuroraBackground pokażą jednolite ciemne
      // tło; owinięte ustawiają własny transparent Scaffold nad gradientem.
      scaffoldBackgroundColor: AppColors.bgSolid,

      extensions: [AppSemanticColors.aurora],

      // Typografia — tabular figures dla kwot finansowych (skala wg design.md)
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      // Karty: frost (przezroczystość + border), radius 22, elevation 0, BEZ blur
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.frostBorder),
        ),
        color: AppColors.frost1,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // FilledButton — akcent, radius 16
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentSolid,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // FloatingActionButton „Dodaj" — jasny akcent + ciemny tekst (jak pigułki w makiecie)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentViolet,
        foregroundColor: AppColors.onAccent,
        elevation: 2,
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.frostBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // TextField — tło frost, radius 12, focus akcent
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.frost1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.frostBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.frostBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentViolet, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // AppBar — transparentny (gradient widoczny pod spodem)
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // Dialogi (AlertDialog) — nieprzezroczysta uniesiona powierzchnia + border frost
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.frostBorder),
        ),
      ),

      // Bottom sheets — to samo tło, by nie zlewały się z przyciemnieniem
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        modalBackgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      // Date picker — osobny ThemeData (NIE dialogTheme); bez tego spada do
      // domyślnego półprzezroczystego tła.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: AppColors.frostBorder),
        ),
      ),

      // Time picker — analogicznie (gdyby kiedyś użyty)
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surfaceElevated,
      ),

      // Menu / popup / dropdown — uniesiona powierzchnia zamiast domyślnej
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(color: AppColors.frostBorder),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      // SnackBar — uniesiona powierzchnia, jasny tekst, pływający
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.frostBorder),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentViolet,
      ),

      // Zaznaczanie tekstu — akcent
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accentViolet,
        selectionColor: AppColors.accentViolet.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.accentViolet,
      ),

      // NavigationBar — placeholder do czasu GlassNavBar (Checkpoint 2)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgSolid,
        indicatorColor: AppColors.accentViolet.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.frostBorder,
        thickness: 1,
        space: 1,
      ),

      // ListTile — ikony akcentowe, jasny tekst (Ustawienia w stylu Aurora)
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accentViolet,
        textColor: AppColors.textPrimary,
      ),

      // Switch — tor aktywny w akcencie, biała gałka
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accentSolid : AppColors.frost2,
        ),
        trackOutlineColor: WidgetStateProperty.all(AppColors.frostBorder),
      ),

      // Radio — akcent
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accentViolet : AppColors.textMuted,
        ),
      ),

      // Chipy filtrów — frost; aktywny = akcent z ciemnym tekstem
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.frost2,
        selectedColor: AppColors.accentSolid,
        side: BorderSide(color: AppColors.frostBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: AppColors.onAccent),
        checkmarkColor: AppColors.onAccent,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Zakładki (TabBar) — wskaźnik akcentowy
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accentViolet,
        dividerColor: AppColors.frostBorder,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),
    );
  }
}
