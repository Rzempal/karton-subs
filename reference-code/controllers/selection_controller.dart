import 'package:flutter/foundation.dart';

/// Kontroler stanu trybu zaznaczania (selection mode)
/// Używany do masowej edycji leków (usuwanie, etykiety)
class SelectionController extends ChangeNotifier {
  final Set<String> _selectedIds = {};
  bool _isActive = false;

  /// Czy tryb zaznaczania jest aktywny
  bool get isActive => _isActive;

  /// Zbiór ID zaznaczonych leków (read-only)
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// Liczba zaznaczonych elementów
  int get selectedCount => _selectedIds.length;

  /// Wchodzi w tryb zaznaczania z pierwszym zaznaczonym elementem
  void enterMode(String initialId) {
    if (_isActive) return;
    _isActive = true;
    _selectedIds.add(initialId);
    notifyListeners();
  }

  /// Wychodzi z trybu zaznaczania i czyści zaznaczenie
  void exitMode() {
    _isActive = false;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Przełącza zaznaczenie danego elementu (toggle)
  void toggle(String id) {
    if (!_isActive) return;
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      // Auto-exit jeśli nie ma zaznaczonych
      if (_selectedIds.isEmpty) {
        _isActive = false;
      }
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  /// Zaznacza wszystkie przekazane elementy
  void selectAll(List<String> allIds) {
    if (!_isActive) return;
    _selectedIds.addAll(allIds);
    notifyListeners();
  }

  /// Usuwa wszystkie zaznaczenia (ale pozostaje w trybie selection)
  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Sprawdza czy dany element jest zaznaczony
  bool isSelected(String id) => _selectedIds.contains(id);
}
