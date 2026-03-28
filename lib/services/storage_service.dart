// storage_service.dart v0.001 Hive CRUD dla subskrypcji i kategorii

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import 'app_logger.dart';

/// Serwis do przechowywania danych lokalnie (Hive)
class StorageService {
  static final Logger _log = AppLogger.getLogger('StorageService');
  static const String _subscriptionsBoxName = 'subscriptions';
  static const String _categoriesBoxName = 'categories';
  static const String _settingsBoxName = 'settings';

  late Box<String> _subscriptionsBox;
  late Box<String> _categoriesBox;
  late Box<dynamic> _settingsBox;

  /// Notyfikator zmian trybu wydajności
  final ValueNotifier<bool> performanceModeNotifier = ValueNotifier(false);

  /// Inicjalizacja Hive
  Future<void> init() async {
    await Hive.initFlutter();
    _subscriptionsBox = await Hive.openBox<String>(_subscriptionsBoxName);
    _categoriesBox = await Hive.openBox<String>(_categoriesBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);

    performanceModeNotifier.value = performanceMode;

    // Seed predefined categories if empty
    if (_categoriesBox.isEmpty) {
      await _seedCategories();
    }
  }

  Future<void> _seedCategories() async {
    _log.info('Seeding predefined categories');
    for (final category in PredefinedCategories.all) {
      await _categoriesBox.put(category.id, jsonEncode(category.toJson()));
    }
    _invalidateCategoriesCache();
  }

  // ==================== SETTINGS ====================

  /// Czy tooltip pomocy był już pokazany
  bool get helpTooltipShown =>
      _settingsBox.get('helpTooltipShown', defaultValue: false) as bool;

  set helpTooltipShown(bool value) {
    _settingsBox.put('helpTooltipShown', value);
  }

  /// Tryb wydajności
  bool get performanceMode =>
      _settingsBox.get('performanceMode', defaultValue: false) as bool;

  set performanceMode(bool value) {
    _settingsBox.put('performanceMode', value);
    performanceModeNotifier.value = value;
  }

  /// Domyślna waluta
  Currency get defaultCurrency {
    final saved = _settingsBox.get('defaultCurrency') as String?;
    if (saved == null) return Currency.PLN;
    return Currency.values.firstWhere(
      (c) => c.name == saved,
      orElse: () => Currency.PLN,
    );
  }

  set defaultCurrency(Currency value) {
    _settingsBox.put('defaultCurrency', value.name);
  }

  /// Limit budżetowy (opcjonalny, miesięczny)
  double? get budgetLimit {
    final value = _settingsBox.get('budgetLimit');
    if (value == null) return null;
    return (value as num).toDouble();
  }

  set budgetLimit(double? value) {
    if (value == null) {
      _settingsBox.delete('budgetLimit');
    } else {
      _settingsBox.put('budgetLimit', value);
    }
  }

  /// VersionCode ostatniej odrzuconej aktualizacji
  int get dismissedUpdateVersionCode =>
      _settingsBox.get('dismissedUpdateVersionCode', defaultValue: 0) as int;

  set dismissedUpdateVersionCode(int value) {
    _settingsBox.put('dismissedUpdateVersionCode', value);
  }

  // ==================== SUBSCRIPTIONS ====================

  List<Subscription>? _subscriptionsCache;

  /// Pobiera wszystkie subskrypcje (z cache)
  List<Subscription> getSubscriptions() {
    if (_subscriptionsCache != null) {
      return List.unmodifiable(_subscriptionsCache!);
    }
    _subscriptionsCache = _deserializeSubscriptions();
    return List.unmodifiable(_subscriptionsCache!);
  }

  List<Subscription> _deserializeSubscriptions() {
    final List<Subscription> subscriptions = [];
    for (final key in _subscriptionsBox.keys) {
      final json = _subscriptionsBox.get(key);
      if (json != null) {
        try {
          subscriptions.add(Subscription.fromJson(jsonDecode(json)));
        } catch (e) {
          _log.warning('Failed to deserialize subscription $key: $e');
        }
      }
    }
    return subscriptions;
  }

  void _invalidateSubscriptionsCache() {
    _subscriptionsCache = null;
  }

  /// Zapisuje subskrypcję
  Future<void> saveSubscription(Subscription subscription) async {
    await _subscriptionsBox.put(
      subscription.id,
      jsonEncode(subscription.toJson()),
    );
    _invalidateSubscriptionsCache();
  }

  /// Usuwa subskrypcję
  Future<void> deleteSubscription(String id) async {
    await _subscriptionsBox.delete(id);
    _invalidateSubscriptionsCache();
  }

  /// Usuwa wiele subskrypcji
  Future<void> deleteSubscriptions(List<String> ids) async {
    for (final id in ids) {
      await _subscriptionsBox.delete(id);
    }
    _invalidateSubscriptionsCache();
  }

  /// Czyści wszystkie subskrypcje
  Future<void> clearSubscriptions() async {
    await _subscriptionsBox.clear();
    _invalidateSubscriptionsCache();
  }

  /// Importuje subskrypcje z listy
  Future<int> importSubscriptions(List<Subscription> subscriptions) async {
    int count = 0;
    for (final subscription in subscriptions) {
      await _subscriptionsBox.put(
        subscription.id,
        jsonEncode(subscription.toJson()),
      );
      count++;
    }
    _invalidateSubscriptionsCache();
    return count;
  }

  // ==================== CATEGORIES ====================

  List<Category>? _categoriesCache;

  /// Pobiera wszystkie kategorie (posortowane po kolejności, z cache)
  List<Category> getCategories() {
    if (_categoriesCache != null) return List.unmodifiable(_categoriesCache!);
    _categoriesCache = _deserializeCategories();
    return List.unmodifiable(_categoriesCache!);
  }

  List<Category> _deserializeCategories() {
    final List<Category> categories = [];
    for (final key in _categoriesBox.keys) {
      final json = _categoriesBox.get(key);
      if (json != null) {
        try {
          categories.add(Category.fromJson(jsonDecode(json)));
        } catch (e) {
          _log.warning('Failed to deserialize category $key: $e');
        }
      }
    }
    categories.sort((a, b) => a.order.compareTo(b.order));
    return categories;
  }

  void _invalidateCategoriesCache() {
    _categoriesCache = null;
  }

  /// Zapisuje kategorię
  Future<void> saveCategory(Category category) async {
    await _categoriesBox.put(category.id, jsonEncode(category.toJson()));
    _invalidateCategoriesCache();
  }

  /// Usuwa kategorię i czyści referencje w subskrypcjach
  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    _invalidateCategoriesCache();

    // Usuń referencje z subskrypcji
    final subscriptions = getSubscriptions();
    for (final sub in subscriptions) {
      if (sub.categoryId == id) {
        await saveSubscription(sub.copyWith(clearCategoryId: true));
      }
    }
  }

  /// Pobiera kategorię po ID
  Category? getCategoryById(String id) {
    final categories = getCategories();
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Zapisuje nową kolejność kategorii
  Future<void> reorderCategories(List<Category> categories) async {
    for (int i = 0; i < categories.length; i++) {
      final updated = categories[i].copyWith(order: i);
      await saveCategory(updated);
    }
  }

  // ==================== EXPORT / IMPORT ====================

  /// Eksportuje wszystkie dane do JSON (pretty-printed)
  String exportToJson() {
    final subscriptions = getSubscriptions();
    final categories = getCategories();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': 1,
    });
  }

  /// Importuje dane z JSON
  Future<int> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    int count = 0;

    // Import subscriptions
    final subscriptionsRaw = data['subscriptions'] as List<dynamic>?;
    if (subscriptionsRaw != null) {
      for (final raw in subscriptionsRaw) {
        try {
          final sub = Subscription.fromJson(raw as Map<String, dynamic>);
          await saveSubscription(sub);
          count++;
        } catch (e) {
          _log.warning('Failed to import subscription: $e');
        }
      }
    }

    // Import categories
    final categoriesRaw = data['categories'] as List<dynamic>?;
    if (categoriesRaw != null) {
      for (final raw in categoriesRaw) {
        try {
          final cat = Category.fromJson(raw as Map<String, dynamic>);
          await saveCategory(cat);
        } catch (e) {
          _log.warning('Failed to import category: $e');
        }
      }
    }

    // Legacy support: try 'leki' key for APPteczka format
    // (skip — incompatible domain)

    return count;
  }
}
