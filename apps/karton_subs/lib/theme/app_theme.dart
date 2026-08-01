import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Styl pasków systemowych (stan u góry, nawigacja u dołu) dla danej palety.
///
/// Ikony tych pasków maluje SYSTEM, więc aplikacja musi mu powiedzieć, na jakim
/// tle stoją. Do czasu usunięcia pasków tytułu (ADR-026) robił to za nas każdy
/// `AppBar`; potem ekrany robocze nie deklarowały nic i na jasnym motywie
/// zostawały białe ikony na białym tle — nieczytelne.
SystemUiOverlayStyle systemOverlayStyleFor(AuroraPalette palette) {
  final isLight = palette.brightness == Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Android pyta o jasność IKON, iOS o jasność TŁA — stąd odwrotne wartości
    // tej samej sytuacji.
    statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
    systemNavigationBarIconBrightness: isLight
        ? Brightness.dark
        : Brightness.light,
  );
}

/// Aurora — design system z obsługą wielu motywow (ADR-010, zastepuje ADR-005).
///
/// Cztery motywy w siatce 2x2: {Purple, Blue} x {Light, Frost}.
/// - Frost = ciemne tlo + powierzchnie polprzezroczyste + jasny tekst.
/// - Light = jasne tlo + jasne karty + ciemny tekst.
///
/// Mechanizm: [AppColors] eksponuje tokeny jako statyczne gettery czytajace
/// aktywna [AuroraPalette] ([AppColors.active]). Przelacznik podmienia palete
/// (ThemeProvider) i przebudowuje MaterialApp — dzieki czemu ~145 wywolan
/// `AppColors.X` w kodzie dziala bez zmian. Swiadomy, pragmatyczny wybor zamiast
/// pelnego ThemeExtension (mniej refactoru); `AppSemanticColors` pozostaje dla
/// `context.semanticColors`.

/// Paleta jednego motywu — wszystkie tokeny kolorystyczne.
class AuroraPalette {
  final String id;
  final String label;
  final Brightness brightness;

  final Color bgSolid;
  final Color surfaceElevated;
  final List<Color> bgGradientColors;
  final Color glow1;
  final Color glow2;

  final Color frost1;
  final Color frost2;
  final Color frostBorder;
  final Color frostBorderStrong;
  final Color navGlass;

  /// Akcent glowny (historyczna nazwa „violet"; w motywach Blue to blekit).
  final Color accentViolet;
  final Color accentCyan;
  final Color accentSolid;
  final List<Color> accentGradientColors;
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color positive;
  final Color negative;
  final Color warning;
  final Color trial;

  final List<Color> chartColors;
  final Color barIdle;
  final List<Color> barHighlightColors;

  const AuroraPalette({
    required this.id,
    required this.label,
    required this.brightness,
    required this.bgSolid,
    required this.surfaceElevated,
    required this.bgGradientColors,
    required this.glow1,
    required this.glow2,
    required this.frost1,
    required this.frost2,
    required this.frostBorder,
    required this.frostBorderStrong,
    required this.navGlass,
    required this.accentViolet,
    required this.accentCyan,
    required this.accentSolid,
    required this.accentGradientColors,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.trial,
    required this.chartColors,
    required this.barIdle,
    required this.barHighlightColors,
  });

  LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: bgGradientColors,
        stops: const [0.0, 0.52, 1.0],
      );

  LinearGradient get accentGradient =>
      LinearGradient(colors: accentGradientColors);

  LinearGradient get barHighlight => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: barHighlightColors,
      );

  bool get isLight => brightness == Brightness.light;
}

/// Tryb jasnosci aplikacji.
enum AuroraMode { light, dark }

/// Mechanika trybu — wspolna dla wszystkich kolorow (powierzchnie, tekst,
/// bordery, semantyka, jasnosc). Tekst/bordery sa NEUTRALNE (bez hue per kolor)
/// — swiadome uproszczenie; hue mozna dodac do akcentu w razie potrzeby.
class _ModeColors {
  final Brightness brightness;
  final Color frost1, frost2, frostBorder, frostBorderStrong, navGlass;
  final Color textPrimary, textSecondary, textMuted;
  final Color positive, negative, warning, trial;
  final Color barIdle;
  const _ModeColors({
    required this.brightness,
    required this.frost1,
    required this.frost2,
    required this.frostBorder,
    required this.frostBorderStrong,
    required this.navGlass,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.trial,
    required this.barIdle,
  });
}

/// Kolor + tlo akcentu dla jednego trybu (jasnego LUB ciemnego).
class AccentColors {
  final Color accentViolet, accentCyan, accentSolid, onAccent;
  final List<Color> accentGradientColors;
  final Color bgSolid, surfaceElevated;
  final List<Color> bgGradientColors;
  final Color glow1, glow2;
  final List<Color> chartColors;
  final List<Color> barHighlightColors;
  const AccentColors({
    required this.accentViolet,
    required this.accentCyan,
    required this.accentSolid,
    required this.onAccent,
    required this.accentGradientColors,
    required this.bgSolid,
    required this.surfaceElevated,
    required this.bgGradientColors,
    required this.glow1,
    required this.glow2,
    required this.chartColors,
    required this.barHighlightColors,
  });
}

/// Kolor (accent) — niesie warianty dla trybu jasnego i ciemnego.
/// Dodanie nowego koloru = jeden taki obiekt → automatycznie 2 motywy.
class AuroraAccent {
  final String id;
  final String label;

  /// Kolor dostepny tylko w trybie ciemnym (np. OLED — czysta czern).
  /// Wymusza tryb ciemny i wyszarza wybor trybu w UI.
  final bool darkOnly;

  final AccentColors dark;
  final AccentColors light;
  const AuroraAccent({
    required this.id,
    required this.label,
    this.darkOnly = false,
    required this.dark,
    required this.light,
  });
  AccentColors _forMode(AuroraMode m) => m == AuroraMode.dark ? dark : light;

  /// Gradient do podgladu koloru w UI (kafelek): ciemne tlo motywu → akcent.
  /// Rozpoznawalny bez nazwy: Purple=czern→fiolet, Laguna=czern→blekit, OLED=czern→biel.
  LinearGradient get previewGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [dark.bgSolid, dark.accentSolid],
      );
}

/// Definicje trybow i kolorow + kompozycja w [AuroraPalette].
class AuroraThemes {
  AuroraThemes._();

  // ── Mechanika trybow (wspolna dla kolorow) ──────────────────────────────
  static const _darkMode = _ModeColors(
    brightness: Brightness.dark,
    frost1: Color(0x12FFFFFF), // white @ 0.07
    frost2: Color(0x1AFFFFFF), // white @ 0.10
    frostBorder: Color(0x24FFFFFF), // white @ 0.14
    frostBorderStrong: Color(0x33FFFFFF), // white @ 0.20
    navGlass: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFF1F2F8),
    textSecondary: Color(0xFFC3C6D4),
    textMuted: Color(0xFF9AA0B2),
    positive: Color(0xFF34D399),
    negative: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    trial: Color(0xFF60A5FA),
    barIdle: Color(0x1FFFFFFF), // white @ 0.12
  );

  static const _lightMode = _ModeColors(
    brightness: Brightness.light,
    frost1: Color(0xC7FFFFFF), // white @ 0.78
    frost2: Color(0x8CFFFFFF), // white @ 0.55
    frostBorder: Color(0x1F000000), // black @ 0.12 (neutralny)
    frostBorderStrong: Color(0x33000000),
    navGlass: Color(0xD1FFFFFF),
    textPrimary: Color(0xFF232838),
    textSecondary: Color(0xFF54586A),
    textMuted: Color(0xFF868B9E),
    positive: Color(0xFF16A34A),
    negative: Color(0xFFDC2626),
    warning: Color(0xFFB45309),
    trial: Color(0xFF2563EB),
    barIdle: Color(0x1A000000), // black @ ~0.10
  );

  // ── Kolory (accent) — kazdy z wariantem dark i light ────────────────────
  static const purple = AuroraAccent(
    id: 'purple',
    label: 'Purple Green',
    dark: AccentColors(
      accentViolet: Color(0xFFA78BFA),
      accentCyan: Color(0xFF5EEAD4),
      accentSolid: Color(0xFF8B7BF7),
      onAccent: Color(0xFF1B1240),
      accentGradientColors: [Color(0xFFC4B5FD), Color(0xFF5EEAD4)],
      bgSolid: Color(0xFF0E0A1F),
      surfaceElevated: Color(0xFF231C49),
      bgGradientColors: [Color(0xFF241B4B), Color(0xFF16113A), Color(0xFF0B0822)],
      glow1: Color(0x737C5CFF),
      glow2: Color(0x4022D3EE),
      chartColors: [
        Color(0xFFA78BFA), Color(0xFF5EEAD4), Color(0xFF60A5FA),
        Color(0xFFFB923C), Color(0xFF34D399), Color(0xFFF472B6),
      ],
      barHighlightColors: [Color(0xFFA78BFA), Color(0xFF5EEAD4)],
    ),
    light: AccentColors(
      accentViolet: Color(0xFF7C6CF5),
      accentCyan: Color(0xFFB0A0FF),
      accentSolid: Color(0xFF7C6CF5),
      onAccent: Color(0xFFFFFFFF),
      accentGradientColors: [Color(0xFF7C6CF5), Color(0xFFB0A0FF)],
      bgSolid: Color(0xFFECE6F6),
      surfaceElevated: Color(0xFFFFFFFF),
      bgGradientColors: [Color(0xFFE9E3FB), Color(0xFFEFE6F6), Color(0xFFFBE9EF)],
      glow1: Color(0x4DA78BFA),
      glow2: Color(0x2EF472B6),
      chartColors: [
        Color(0xFF7C6CF5), Color(0xFF0D9488), Color(0xFF2563EB),
        Color(0xFFEA580C), Color(0xFF16A34A), Color(0xFFDB2777),
      ],
      barHighlightColors: [Color(0xFF7C6CF5), Color(0xFFB0A0FF)],
    ),
  );

  static const blue = AuroraAccent(
    id: 'blue',
    label: 'Laguna Ocean',
    dark: AccentColors(
      accentViolet: Color(0xFF38BDF8),
      accentCyan: Color(0xFF2DD4BF),
      accentSolid: Color(0xFF38BDF8),
      onAccent: Color(0xFF06283B),
      accentGradientColors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
      bgSolid: Color(0xFF0C1A2A),
      surfaceElevated: Color(0xFF14304C),
      bgGradientColors: [Color(0xFF22466E), Color(0xFF173353), Color(0xFF0E2034)],
      glow1: Color(0x4D38BDF8),
      glow2: Color(0x3814B8A6),
      chartColors: [
        Color(0xFF38BDF8), Color(0xFF2DD4BF), Color(0xFF60A5FA),
        Color(0xFFFB923C), Color(0xFF34D399), Color(0xFFF472B6),
      ],
      barHighlightColors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
    ),
    light: AccentColors(
      accentViolet: Color(0xFF0284C7),
      accentCyan: Color(0xFF2DD4BF),
      accentSolid: Color(0xFF0284C7),
      onAccent: Color(0xFF06283B),
      accentGradientColors: [Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
      bgSolid: Color(0xFFE4EDF7),
      surfaceElevated: Color(0xFFFFFFFF),
      bgGradientColors: [Color(0xFFE2EDFB), Color(0xFFE8F2FA), Color(0xFFE0F3F0)],
      glow1: Color(0x4738BDF8),
      glow2: Color(0x2E2DD4BF),
      chartColors: [
        Color(0xFF0284C7), Color(0xFF0D9488), Color(0xFF2563EB),
        Color(0xFFEA580C), Color(0xFF16A34A), Color(0xFFDB2777),
      ],
      barHighlightColors: [Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
    ),
  );

  // Mono — neutralny czarno-bialy. Ciemny = czysta czern (korzysc OLED:
  // wygaszone piksele), jasny = czysta biel (jak shadcn Default). Oba tryby.
  static const _monoDark = AccentColors(
    accentViolet: Color(0xFFE5E5E5),
    accentCyan: Color(0xFFA3A3A3),
    accentSolid: Color(0xFFE5E5E5),
    onAccent: Color(0xFF000000),
    accentGradientColors: [Color(0xFFF5F5F5), Color(0xFFA3A3A3)],
    bgSolid: Color(0xFF000000),
    surfaceElevated: Color(0xFF121212),
    bgGradientColors: [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)],
    glow1: Color(0x0AFFFFFF),
    glow2: Color(0x08FFFFFF),
    chartColors: [
      Color(0xFFE5E5E5), Color(0xFF60A5FA), Color(0xFF2DD4BF),
      Color(0xFFFB923C), Color(0xFF34D399), Color(0xFFF472B6),
    ],
    barHighlightColors: [Color(0xFFF5F5F5), Color(0xFFA3A3A3)],
  );

  static const _monoLight = AccentColors(
    accentViolet: Color(0xFF171717),
    accentCyan: Color(0xFF404040),
    accentSolid: Color(0xFF171717),
    onAccent: Color(0xFFFFFFFF),
    accentGradientColors: [Color(0xFF171717), Color(0xFF404040)],
    // Tlo lekko szare (nie czysta biel), by biale karty sie odcinaly.
    bgSolid: Color(0xFFF4F4F6),
    surfaceElevated: Color(0xFFFFFFFF),
    bgGradientColors: [Color(0xFFF7F7F9), Color(0xFFF2F2F5), Color(0xFFEDEDF1)],
    glow1: Color(0x08000000),
    glow2: Color(0x05000000),
    chartColors: [
      Color(0xFF171717), Color(0xFF2563EB), Color(0xFF0D9488),
      Color(0xFFEA580C), Color(0xFF16A34A), Color(0xFFDB2777),
    ],
    barHighlightColors: [Color(0xFF171717), Color(0xFF404040)],
  );

  static const mono = AuroraAccent(
    id: 'mono',
    label: 'Mono',
    dark: _monoDark,
    light: _monoLight,
  );

  /// Wbudowane kolory (statyczne). Material You dokladany dynamicznie (gdy dostepny).
  static const accents = [purple, blue, mono];

  static AuroraAccent accentById(String? id) =>
      accents.firstWhere((a) => a.id == id, orElse: () => purple);

  /// Akcent Material You z systemowych [ColorScheme] (dynamic_color, Android 12+):
  /// akcent = primary, tlo z Material surfaces, glow z primary. Mechanika (frost/
  /// tekst/semantyka) pochodzi z trybu — zachowuje tozsamosc Aurora.
  static AuroraAccent materialAccent(ColorScheme light, ColorScheme dark) =>
      AuroraAccent(
        id: 'material',
        label: 'Material You',
        dark: _fromScheme(dark, AuroraMode.dark),
        light: _fromScheme(light, AuroraMode.light),
      );

  static AccentColors _fromScheme(ColorScheme cs, AuroraMode mode) {
    final isDark = mode == AuroraMode.dark;
    return AccentColors(
      accentViolet: cs.primary,
      accentCyan: cs.tertiary,
      accentSolid: cs.primary,
      onAccent: cs.onPrimary,
      accentGradientColors: [cs.primary, cs.tertiary],
      bgSolid: cs.surface,
      surfaceElevated: cs.surfaceContainerHigh,
      bgGradientColors: [
        cs.surfaceContainerHigh,
        cs.surface,
        cs.surfaceContainerLow,
      ],
      glow1: cs.primary.withValues(alpha: isDark ? 0.35 : 0.22),
      glow2: cs.tertiary.withValues(alpha: isDark ? 0.25 : 0.16),
      chartColors: [
        cs.primary, cs.secondary, cs.tertiary,
        cs.error, cs.primaryContainer, cs.tertiaryContainer,
      ],
      barHighlightColors: [cs.primary, cs.tertiary],
    );
  }

  /// Komponuje palete z trybu (mechanika) i koloru (akcent + tlo).
  static AuroraPalette compose(AuroraMode mode, AuroraAccent accent) {
    final m = mode == AuroraMode.dark ? _darkMode : _lightMode;
    final a = accent._forMode(mode);
    return AuroraPalette(
      id: '${accent.id}-${mode == AuroraMode.dark ? 'dark' : 'light'}',
      label: '${accent.label} ${mode == AuroraMode.dark ? 'Dark' : 'Light'}',
      brightness: m.brightness,
      bgSolid: a.bgSolid,
      surfaceElevated: a.surfaceElevated,
      bgGradientColors: a.bgGradientColors,
      glow1: a.glow1,
      glow2: a.glow2,
      frost1: m.frost1,
      frost2: m.frost2,
      frostBorder: m.frostBorder,
      frostBorderStrong: m.frostBorderStrong,
      navGlass: m.navGlass,
      accentViolet: a.accentViolet,
      accentCyan: a.accentCyan,
      accentSolid: a.accentSolid,
      accentGradientColors: a.accentGradientColors,
      onAccent: a.onAccent,
      textPrimary: m.textPrimary,
      textSecondary: m.textSecondary,
      textMuted: m.textMuted,
      positive: m.positive,
      negative: m.negative,
      warning: m.warning,
      trial: m.trial,
      chartColors: a.chartColors,
      barIdle: m.barIdle,
      barHighlightColors: a.barHighlightColors,
    );
  }
}

/// Tokeny kolorystyczne — gettery czytajace aktywny motyw [active].
/// API zgodne wstecz: kod uzywa `AppColors.frost1` itd. bez zmian.
class AppColors {
  AppColors._();

  static AuroraPalette active =
      AuroraThemes.compose(AuroraMode.dark, AuroraThemes.purple);

  static Color get bgSolid => active.bgSolid;
  static Color get surfaceElevated => active.surfaceElevated;
  static LinearGradient get bgGradient => active.bgGradient;
  static Color get glowViolet => active.glow1;
  static Color get glowCyan => active.glow2;

  static Color get frost1 => active.frost1;
  static Color get frost2 => active.frost2;
  static Color get frostBorder => active.frostBorder;
  static Color get frostBorderStrong => active.frostBorderStrong;
  static Color get navGlass => active.navGlass;

  static Color get accentViolet => active.accentViolet;
  static Color get accentCyan => active.accentCyan;
  static Color get accentSolid => active.accentSolid;
  static LinearGradient get accentGradient => active.accentGradient;
  static Color get onAccent => active.onAccent;

  static Color get textPrimary => active.textPrimary;
  static Color get textSecondary => active.textSecondary;
  static Color get textMuted => active.textMuted;

  static Color get positive => active.positive;
  static Color get negative => active.negative;
  static Color get warning => active.warning;
  static Color get trial => active.trial;

  static List<Color> get chartColors => active.chartColors;
  static Color get barIdle => active.barIdle;
  static LinearGradient get barHighlight => active.barHighlight;
}

/// Promienie zaokrągleń (geometria marki Aurora) — jedno źródło prawdy.
class AppRadii {
  AppRadii._();

  static const double card = 22;
  static const double metric = 18;
  static const double tile = 16;
  static const double pill = 30;
  static const double pillAction = 26;
  static const double control = 12;
}

// ── Semantic Color Tokens (theme-aware przez ThemeExtension) ───────────────
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

  /// Buduje zestaw semantyczny z palety motywu.
  factory AppSemanticColors.of(AuroraPalette p) => AppSemanticColors(
        positive: p.positive,
        positiveBg: p.positive.withValues(alpha: 0.14),
        negative: p.negative,
        negativeBg: p.negative.withValues(alpha: 0.14),
        warning: p.warning,
        warningBg: p.warning.withValues(alpha: 0.14),
        textPrimary: p.textPrimary,
        textSecondary: p.textSecondary,
        textMuted: p.textMuted,
        border: p.frostBorder,
        surface: p.frost1,
        surfaceVariant: p.frost2,
        primary: p.accentViolet,
        heroCardBg: p.frost1,
        heroCardText: p.textPrimary,
        heroCardTextSecondary: p.textSecondary,
        trial: p.trial,
        trialBg: p.trial.withValues(alpha: 0.14),
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
      heroCardTextSecondary:
          Color.lerp(heroCardTextSecondary, other.heroCardTextSecondary, t)!,
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

  /// Buduje ThemeData dla podanej palety. NIE ustawia [AppColors.active] —
  /// robi to jawnie warstwa nadrzedna (main) wg faktycznego trybu, bo przy
  /// ThemeMode.system budowane sa oba motywy (jasny i ciemny).
  static ThemeData build(AuroraPalette palette) {
    final p = palette;

    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accentViolet,
      onPrimary: p.onAccent,
      primaryContainer: p.accentSolid,
      onPrimaryContainer: p.textPrimary,
      secondary: p.accentCyan,
      onSecondary: p.onAccent,
      secondaryContainer: p.frost2,
      onSecondaryContainer: p.textPrimary,
      error: p.negative,
      onError: p.isLight ? const Color(0xFFFFFFFF) : p.bgSolid,
      errorContainer: p.negative.withValues(alpha: 0.14),
      onErrorContainer: p.negative,
      surface: p.bgSolid,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.frostBorder,
      outlineVariant: p.frostBorder,
      surfaceContainerHighest: p.frost2,
      surfaceContainerHigh: p.frost2,
      surfaceContainer: p.frost1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bgSolid,
      extensions: [AppSemanticColors.of(p)],

      // Przejścia tras: fade-through (stary ekran znika CAŁKOWICIE, dopiero
      // potem pojawia się nowy — fazy się nie nakładają). Domyślny androidowy
      // zoom pokazuje oba ekrany jednocześnie, a przy przezroczystych
      // Scaffoldach (wspólne tło Aurora) treść poprzedniego ekranu prześwituje
      // jak duch podczas powrotu. fillColor transparent — tło daje Aurora.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: Colors.transparent,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: Colors.transparent,
          ),
        },
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: p.frostBorder),
        ),
        color: p.frost1,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accentSolid,
          foregroundColor: p.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accentViolet,
        foregroundColor: p.onAccent,
        elevation: 2,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.frostBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.frost1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.frostBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.frostBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.accentViolet, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        // Bez tego pasek tytułu (podekrany Ustawień, Planner) zgadywałby kolor
        // ikon systemowych z własnego — przezroczystego — tła.
        systemOverlayStyle: systemOverlayStyleFor(p),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: p.frostBorder),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        modalBackgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: p.frostBorder),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surfaceElevated,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(color: p.frostBorder),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: p.frostBorder),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accentViolet),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accentViolet,
        selectionColor: p.accentViolet.withValues(alpha: 0.3),
        selectionHandleColor: p.accentViolet,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bgSolid,
        indicatorColor: p.accentViolet.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.frostBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.accentViolet,
        textColor: p.textPrimary,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accentSolid : p.frost2,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.frostBorder),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accentViolet : p.textMuted,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.frost2,
        selectedColor: p.accentSolid,
        side: BorderSide(color: p.frostBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Zaznaczony chip ma tlo akcentu (ciemne) — tekst musi byc kontrastowy
        // (onAccent), inaczej ciemny tekst znika na ciemnym akcencie. FilterChip
        // nie uzywa secondaryLabelStyle dla zaznaczenia, wiec rozwiazujemy kolor
        // stanowo przez WidgetStateColor (zwykly TextStyle zachowuje fontSize,
        // a chip rozwiazuje sam kolor per-stan).
        labelStyle: TextStyle(
          fontSize: 12,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.onAccent
                : p.textSecondary,
          ),
        ),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: p.onAccent),
        checkmarkColor: p.onAccent,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textMuted,
        indicatorColor: p.accentViolet,
        dividerColor: p.frostBorder,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),
    );
  }
}
