import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'storage_service.dart';

/// Motyw aplikacji w dwoch wymiarach (ADR-010): Tryb x Kolor.
/// - Tryb ([ThemeMode]): jasny / ciemny / systemowy.
/// - Kolor ([AuroraAccent]): purple / blue / mono / **Material You** (gdy
///   urzadzenie wspiera dynamic_color — Android 12+; akcent + tlo z systemu,
///   mechanika z trybu).
class ThemeProvider extends ChangeNotifier {
  final StorageService _storage;
  // Schematy systemowe (Material You) — wczytywane ASYNCHRONICZNIE przez
  // dynamic_color, wiec aktualizowane po starcie metoda [setDynamic].
  ColorScheme? _lightDynamic;
  ColorScheme? _darkDynamic;
  ThemeMode _mode;
  String _accentId;

  ThemeProvider(this._storage)
      : _mode = _parseMode(_storage.getThemeMode()),
        _accentId = _storage.getAccentId();

  /// Aktualizuje schematy systemowe gdy dynamic_color je dostarczy (po starcie).
  void setDynamic(ColorScheme? light, ColorScheme? dark) {
    if (_lightDynamic == light && _darkDynamic == dark) return;
    _lightDynamic = light;
    _darkDynamic = dark;
    notifyListeners();
  }

  /// Czy urzadzenie udostepnia kolor systemowy (Material You, Android 12+).
  bool get materialAvailable =>
      _lightDynamic != null && _darkDynamic != null;

  AuroraAccent? get _material => materialAvailable
      ? AuroraThemes.materialAccent(_lightDynamic!, _darkDynamic!)
      : null;

  /// Dostepne kolory: wbudowane + Material You (gdy wspierany).
  List<AuroraAccent> get accents =>
      [...AuroraThemes.accents, if (materialAvailable) _material!];

  /// Aktywny kolor (resolve id → obiekt; Material You gdy dostepny, inaczej
  /// fallback na Purple — np. gdy zapisano material, a urzadzenie go nie wspiera).
  AuroraAccent get accent {
    if (_accentId == 'material') return _material ?? AuroraThemes.purple;
    return AuroraThemes.accentById(_accentId);
  }

  ThemeMode get mode => _mode;

  /// Tryb dla MaterialApp — kolor darkOnly wymusza ciemny.
  ThemeMode get effectiveThemeMode =>
      accent.darkOnly ? ThemeMode.dark : _mode;

  ThemeData get lightTheme =>
      AppTheme.build(AuroraThemes.compose(AuroraMode.light, accent));
  ThemeData get darkTheme =>
      AppTheme.build(AuroraThemes.compose(AuroraMode.dark, accent));

  /// Faktyczny tryb wg wyboru + jasnosci systemu (do ustawienia AppColors.active).
  AuroraMode effectiveMode(Brightness platform) {
    if (accent.darkOnly) return AuroraMode.dark;
    switch (_mode) {
      case ThemeMode.light:
        return AuroraMode.light;
      case ThemeMode.dark:
        return AuroraMode.dark;
      case ThemeMode.system:
        return platform == Brightness.dark ? AuroraMode.dark : AuroraMode.light;
    }
  }

  AuroraPalette effectivePalette(Brightness platform) =>
      AuroraThemes.compose(effectiveMode(platform), accent);

  void setMode(ThemeMode m) {
    if (_mode == m) return;
    _mode = m;
    _storage.setThemeMode(m.name);
    notifyListeners();
  }

  void setAccent(AuroraAccent a) {
    if (_accentId == a.id) return;
    _accentId = a.id;
    _storage.setAccentId(a.id);
    notifyListeners();
  }

  static ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}
