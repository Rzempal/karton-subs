import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider zarządzający motywem aplikacji
/// Persystuje wybór w SharedPreferences (jak localStorage w web)
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _warningStyleKey = 'warning_style_bold';

  ThemeMode _themeMode = ThemeMode.system;
  bool _warningStyleBold = true;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;

  /// Czy ostrzeżenia są w trybie "wyrazistym" (outline + gradient tła)
  bool get warningStyleBold => _warningStyleBold;

  /// Czy aktualnie jest ciemny motyw
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Inicjalizacja - wczytanie zapisanego motywu
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_themeKey);

    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    _warningStyleBold = _prefs?.getBool(_warningStyleKey) ?? true;
    notifyListeners();
  }

  /// Przełącz między light/dark
  void toggleTheme() {
    if (isDarkMode) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  /// Ustaw konkretny tryb
  /// UWAGA: notifyListeners() na końcu - po zapisie do storage
  /// eliminuje lag przy przełączaniu motywu
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    String? value;
    switch (mode) {
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.system:
        value = null;
        break;
    }

    // Najpierw zapisz do storage (I/O)
    if (value != null) {
      await _prefs?.setString(_themeKey, value);
    } else {
      await _prefs?.remove(_themeKey);
    }

    // Potem powiadom UI (rebuild po zakończeniu I/O)
    notifyListeners();
  }

  /// Przełącz styl ostrzeżeń (wyrazisty ↔ minimalistyczny)
  Future<void> toggleWarningStyle() async {
    _warningStyleBold = !_warningStyleBold;
    await _prefs?.setBool(_warningStyleKey, _warningStyleBold);
    notifyListeners();
  }
}
