// REFERENCE: Ten plik pochodzi z "Karton z lekami" (APPteczka).
// Wymaga adaptacji do domeny subskrypcji. Zobacz docs/database.md dla nowego modelu.
// Reusable: wzorzec Hive + cache + lazy deserialization, settings box, ValueNotifier.
// Do wymiany: Medicine/Label boxes -> Subscription/Category boxes, AI settings -> usunac.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../models/medicine.dart';
import '../models/label.dart';
import 'app_logger.dart';

/// Serwis do przechowywania danych lokalnie (Hive)
class StorageService {
  static final Logger _log = AppLogger.getLogger('StorageService');
  static const String _medicinesBoxName = 'medicines';
  static const String _labelsBoxName = 'labels';
  static const String _settingsBoxName = 'settings';

  late Box<String> _medicinesBox;
  late Box<String> _labelsBox;
  late Box<dynamic> _settingsBox;

  /// Notyfikator zmian widoczności FABa
  final ValueNotifier<bool> showBugReportFabNotifier = ValueNotifier(false);

  /// Notyfikator zmian trybu wydajności
  final ValueNotifier<bool> performanceModeNotifier = ValueNotifier(false);

  /// Inicjalizacja Hive
  Future<void> init() async {
    await Hive.initFlutter();
    _medicinesBox = await Hive.openBox<String>(_medicinesBoxName);
    _labelsBox = await Hive.openBox<String>(_labelsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);

    // Inicjalizacja notyfikatorów wartościami z bazy
    showBugReportFabNotifier.value = showBugReportFab;
    performanceModeNotifier.value = performanceMode;
  }

  // ==================== SETTINGS ====================

  /// Czy pokazywać FAB do zgłaszania błędów
  bool get showBugReportFab =>
      _settingsBox.get('showBugReportFab', defaultValue: false) as bool;

  set showBugReportFab(bool value) {
    _settingsBox.put('showBugReportFab', value);
    showBugReportFabNotifier.value = value;
  }

  /// Czy tooltip pomocy był już pokazany (domyślnie false)
  bool get helpTooltipShown =>
      _settingsBox.get('helpTooltipShown', defaultValue: false) as bool;

  set helpTooltipShown(bool value) {
    _settingsBox.put('helpTooltipShown', value);
  }

  /// Tryb wydajności - uproszczone efekty neumorficzne (domyślnie false)
  bool get performanceMode =>
      _settingsBox.get('performanceMode', defaultValue: false) as bool;

  set performanceMode(bool value) {
    _settingsBox.put('performanceMode', value);
    performanceModeNotifier.value = value;
  }

  /// Tryb kalkulatora zapasu: 'manual' (domyślny) lub 'auto'
  /// manual = data zamrożona do kliknięcia "Przelicz"
  /// auto = pieceCount zmniejsza się codziennie o dailyIntake
  String get supplyCalcMode =>
      _settingsBox.get('supplyCalcMode', defaultValue: 'manual') as String;

  set supplyCalcMode(String value) {
    _settingsBox.put('supplyCalcMode', value);
  }

  /// Skrócone etykiety - tylko pierwsza litera na karcie compact (domyślnie false)
  bool get showShortenedLabels =>
      _settingsBox.get('showShortenedLabels', defaultValue: false) as bool;

  set showShortenedLabels(bool value) {
    _settingsBox.put('showShortenedLabels', value);
  }

  // ==================== AI SETTINGS (Developer Tools) ====================

  /// Globalny toggle AI - wyłącza wszystkie funkcje AI
  bool get aiEnabled =>
      _settingsBox.get('aiEnabled', defaultValue: true) as bool;

  set aiEnabled(bool value) {
    _settingsBox.put('aiEnabled', value);
  }

  /// Name Lookup + Background Queue Processing
  bool get aiNameLookupEnabled =>
      _settingsBox.get('aiNameLookupEnabled', defaultValue: true) as bool;

  set aiNameLookupEnabled(bool value) {
    _settingsBox.put('aiNameLookupEnabled', value);
  }

  /// Barcode Scanner Fallback (gdy EAN nieznany)
  bool get aiBarcodeFallbackEnabled =>
      _settingsBox.get('aiBarcodeFallbackEnabled', defaultValue: true) as bool;

  set aiBarcodeFallbackEnabled(bool value) {
    _settingsBox.put('aiBarcodeFallbackEnabled', value);
  }

  /// Product Photo OCR (rozpoznawanie produktu ze zdjęcia)
  bool get aiProductPhotoEnabled =>
      _settingsBox.get('aiProductPhotoEnabled', defaultValue: true) as bool;

  set aiProductPhotoEnabled(bool value) {
    _settingsBox.put('aiProductPhotoEnabled', value);
  }

  /// Expiry Date OCR (rozpoznawanie daty ważności)
  bool get aiExpiryDateOcrEnabled =>
      _settingsBox.get('aiExpiryDateOcrEnabled', defaultValue: true) as bool;

  set aiExpiryDateOcrEnabled(bool value) {
    _settingsBox.put('aiExpiryDateOcrEnabled', value);
  }

  /// Shelf Life Analysis (analiza ulotki PDF)
  bool get aiShelfLifeEnabled =>
      _settingsBox.get('aiShelfLifeEnabled', defaultValue: true) as bool;

  set aiShelfLifeEnabled(bool value) {
    _settingsBox.put('aiShelfLifeEnabled', value);
  }

  // ==================== UPDATE DIALOG ====================

  /// VersionCode ostatniej odrzuconej aktualizacji (dialog "Co nowego?")
  int get dismissedUpdateVersionCode =>
      _settingsBox.get('dismissedUpdateVersionCode', defaultValue: 0) as int;

  set dismissedUpdateVersionCode(int value) {
    _settingsBox.put('dismissedUpdateVersionCode', value);
  }

  // ==================== MEDICINES ====================

  List<Medicine>? _medicinesCache;

  /// Pobiera wszystkie leki (z cache)
  List<Medicine> getMedicines() {
    if (_medicinesCache != null) return List.unmodifiable(_medicinesCache!);
    _medicinesCache = _deserializeMedicines();
    return List.unmodifiable(_medicinesCache!);
  }

  List<Medicine> _deserializeMedicines() {
    final List<Medicine> medicines = [];
    for (final key in _medicinesBox.keys) {
      final json = _medicinesBox.get(key);
      if (json != null) {
        try {
          medicines.add(Medicine.fromJson(jsonDecode(json)));
        } catch (e) {
          // Ignoruj uszkodzone wpisy
        }
      }
    }
    return medicines;
  }

  void _invalidateMedicinesCache() {
    _medicinesCache = null;
  }

  /// Zapisuje lek
  Future<void> saveMedicine(Medicine medicine) async {
    await _medicinesBox.put(medicine.id, jsonEncode(medicine.toJson()));
    _invalidateMedicinesCache();
  }

  /// Usuwa lek
  Future<void> deleteMedicine(String id) async {
    await _medicinesBox.delete(id);
    _invalidateMedicinesCache();
  }

  /// Czyści wszystkie leki
  Future<void> clearMedicines() async {
    await _medicinesBox.clear();
    _invalidateMedicinesCache();
  }

  /// Importuje leki z JSON
  Future<int> importMedicines(List<Medicine> medicines) async {
    int count = 0;
    for (final medicine in medicines) {
      await _medicinesBox.put(medicine.id, jsonEncode(medicine.toJson()));
      count++;
    }
    _invalidateMedicinesCache();
    return count;
  }

  /// Eksportuje wszystkie leki i etykiety do JSON (kompatybilny z web)
  /// Pretty-printed dla czytelności kopii zapasowych
  String exportToJson() {
    final medicines = getMedicines();
    final labels = getLabels();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'leki': medicines.map((m) => m.toJson()).toList(),
      'labels': labels.map((l) => l.toJson()).toList(),
    });
  }

  // ==================== LABELS ====================

  List<UserLabel>? _labelsCache;

  /// Pobiera wszystkie etykiety (posortowane po kolejności, z cache)
  List<UserLabel> getLabels() {
    if (_labelsCache != null) return List.unmodifiable(_labelsCache!);
    _labelsCache = _deserializeLabels();
    return List.unmodifiable(_labelsCache!);
  }

  List<UserLabel> _deserializeLabels() {
    final List<UserLabel> labels = [];
    for (final key in _labelsBox.keys) {
      final json = _labelsBox.get(key);
      if (json != null) {
        try {
          labels.add(UserLabel.fromJson(jsonDecode(json)));
        } catch (e) {
          // Ignoruj uszkodzone wpisy
        }
      }
    }
    labels.sort((a, b) => a.order.compareTo(b.order));
    return labels;
  }

  void _invalidateLabelsCache() {
    _labelsCache = null;
  }

  /// Zapisuje etykietę
  Future<void> saveLabel(UserLabel label) async {
    await _labelsBox.put(label.id, jsonEncode(label.toJson()));
    _invalidateLabelsCache();
  }

  /// Usuwa etykietę
  Future<void> deleteLabel(String id) async {
    await _labelsBox.delete(id);
    _invalidateLabelsCache();

    // Usuń referencje z wszystkich leków
    final medicines = getMedicines();
    for (final medicine in medicines) {
      if (medicine.labels.contains(id)) {
        final updatedLabels = medicine.labels.where((l) => l != id).toList();
        await saveMedicine(medicine.copyWith(labels: updatedLabels));
      }
    }
  }

  /// Aktualizuje etykietę
  Future<void> updateLabel(UserLabel label) async {
    await saveLabel(label);
  }

  /// Pobiera etykiety po ID
  List<UserLabel> getLabelsByIds(List<String> ids) {
    final allLabels = getLabels();
    return allLabels.where((l) => ids.contains(l.id)).toList();
  }

  /// Czyści wszystkie etykiety
  Future<void> clearLabels() async {
    await _labelsBox.clear();
    _invalidateLabelsCache();
  }

  /// Zapisuje nową kolejność etykiet
  Future<void> reorderLabels(List<UserLabel> labels) async {
    for (int i = 0; i < labels.length; i++) {
      final updatedLabel = labels[i].copyWith(order: i);
      await saveLabel(updatedLabel);
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Zwraca nazwy leków jako string "lek1, lek2, lek3"
  String getMedicineNamesString() {
    final medicines = getMedicines();
    return medicines.map((m) => m.nazwa ?? 'Nieznany').join(', ');
  }

  /// Aktualizuje URL ulotki dla leku
  Future<void> updateMedicineLeaflet(String id, String? leafletUrl) async {
    final medicines = getMedicines();
    final index = medicines.indexWhere((m) => m.id == id);
    if (index != -1) {
      final updated = medicines[index].copyWith(leafletUrl: leafletUrl);
      await saveMedicine(updated);
    }
  }

  /// Aktualizuje notatkę leku
  Future<void> updateMedicineNote(String id, String? note) async {
    _log.info('Updating note for medicine $id: $note');
    final medicines = getMedicines();
    final index = medicines.indexWhere((m) => m.id == id);
    if (index != -1) {
      final updated = medicines[index].copyWith(notatka: note);
      await saveMedicine(updated);
    }
  }

  /// Pobiera wszystkie custom tagi (nie predefiniowane)
  List<String> getCustomTags(Set<String> predefinedTags) {
    final allTags = <String>{};
    for (final medicine in getMedicines()) {
      allTags.addAll(medicine.tagi);
    }
    return allTags.where((t) => !predefinedTags.contains(t)).toList()..sort();
  }

  /// Usuwa custom tag ze wszystkich leków
  Future<void> deleteCustomTag(String tag) async {
    final medicines = getMedicines();
    for (final medicine in medicines) {
      if (medicine.tagi.contains(tag)) {
        final updatedTags = medicine.tagi.where((t) => t != tag).toList();
        await saveMedicine(medicine.copyWith(tagi: updatedTags));
      }
    }
  }

  /// Aktualizuje etykiety leku
  Future<void> updateMedicineLabels(String id, List<String> labelIds) async {
    _log.info('Updating labels for medicine $id: $labelIds');
    final medicines = getMedicines();
    final index = medicines.indexWhere((m) => m.id == id);
    if (index != -1) {
      final updated = medicines[index].copyWith(labels: labelIds);
      await saveMedicine(updated);
    }
  }
}
