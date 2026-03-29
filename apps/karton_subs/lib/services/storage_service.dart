import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import 'app_logger.dart';

/// Hive-based storage — wzorzec z APPteczka, zaadaptowany na modele karton-subs.
/// Boxy: 'subscriptions', 'categories', 'settings'.
/// Dane przechowywane jako JSON string (brak type adapters = brak code gen).
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static final _log = AppLogger.get('StorageService');

  late Box<String> _subscriptionsBox;
  late Box<String> _categoriesBox;
  late Box<dynamic> _settingsBox;

  // In-memory cache
  final Map<String, Subscription> _subscriptionsCache = {};
  final Map<String, Category> _categoriesCache = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _subscriptionsBox = await Hive.openBox<String>('subscriptions');
    _categoriesBox = await Hive.openBox<String>('categories');
    _settingsBox = await Hive.openBox('settings');
    _loadSubscriptionsCache();
    _loadCategoriesCache();
    _seedDefaultCategories();
    _initialized = true;
    _log.info('StorageService initialized (${_subscriptionsCache.length} subs, ${_categoriesCache.length} cats)');
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────

  void _loadSubscriptionsCache() {
    _subscriptionsCache.clear();
    for (final key in _subscriptionsBox.keys) {
      try {
        final json = jsonDecode(_subscriptionsBox.get(key as String)!);
        _subscriptionsCache[key] = Subscription.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        _log.warning('Failed to parse subscription $key: $e');
      }
    }
  }

  List<Subscription> getSubscriptions() =>
      List.unmodifiable(_subscriptionsCache.values);

  List<Subscription> getActiveSubscriptions() =>
      _subscriptionsCache.values.where((s) => s.isActive).toList();

  Subscription? getSubscription(String id) => _subscriptionsCache[id];

  Future<void> saveSubscription(Subscription sub) async {
    await _subscriptionsBox.put(sub.id, jsonEncode(sub.toJson()));
    _subscriptionsCache[sub.id] = sub;
    _log.info('Saved subscription: ${sub.name}');
  }

  Future<void> deleteSubscription(String id) async {
    await _subscriptionsBox.delete(id);
    _subscriptionsCache.remove(id);
    _log.info('Deleted subscription: $id');
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  void _loadCategoriesCache() {
    _categoriesCache.clear();
    for (final key in _categoriesBox.keys) {
      try {
        final json = jsonDecode(_categoriesBox.get(key as String)!);
        _categoriesCache[key] = Category.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        _log.warning('Failed to parse category $key: $e');
      }
    }
  }

  void _seedDefaultCategories() {
    if (_categoriesCache.isNotEmpty) return;
    for (final cat in defaultCategories) {
      _categoriesBox.put(cat.id, jsonEncode(cat.toJson()));
      _categoriesCache[cat.id] = cat;
    }
    _log.info('Seeded ${defaultCategories.length} default categories');
  }

  List<Category> getCategories() {
    final cats = _categoriesCache.values.toList();
    cats.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(cats);
  }

  Category? getCategory(String id) => _categoriesCache[id];

  Future<void> saveCategory(Category cat) async {
    await _categoriesBox.put(cat.id, jsonEncode(cat.toJson()));
    _categoriesCache[cat.id] = cat;
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  String getCurrency() => _settingsBox.get('currency', defaultValue: 'PLN') as String;

  Future<void> setCurrency(String currencyCode) async {
    await _settingsBox.put('currency', currencyCode);
  }

  /// Dev-only: override daty do testowania ghost detection
  DateTime? getDevDateOverride() {
    final v = _settingsBox.get('devDateOverride') as String?;
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> setDevDateOverride(DateTime? date) async {
    if (date == null) {
      await _settingsBox.delete('devDateOverride');
    } else {
      await _settingsBox.put('devDateOverride', date.toIso8601String());
    }
  }

  double? getBudgetLimit() {
    final v = _settingsBox.get('budgetLimit');
    return v != null ? (v as num).toDouble() : null;
  }

  Future<void> setBudgetLimit(double? limit) async {
    if (limit == null) {
      await _settingsBox.delete('budgetLimit');
    } else {
      await _settingsBox.put('budgetLimit', limit);
    }
  }

  // ── Analytics helpers ──────────────────────────────────────────────────────

  double getTotalMonthly({String? currencyCode}) {
    final subs = getActiveSubscriptions();
    return subs.fold(0.0, (sum, s) => sum + s.monthlyAmount);
  }

  Map<String, double> getCategoryBreakdown() {
    final result = <String, double>{};
    for (final sub in getActiveSubscriptions()) {
      final key = sub.categoryId ?? 'cat_other';
      result[key] = (result[key] ?? 0.0) + sub.monthlyAmount;
    }
    return result;
  }

  List<Subscription> getGhostSubscriptions() =>
      getActiveSubscriptions().where((s) => s.isGhost).toList();
}
