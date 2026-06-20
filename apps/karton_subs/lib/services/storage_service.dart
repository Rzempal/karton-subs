import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../models/budget_entry.dart';
import 'app_logger.dart';

/// Hive-based storage — wzorzec z APPteczka, zaadaptowany na modele karton-subs.
/// Boxy: 'subscriptions', 'categories', 'payment_methods', 'budget_entries', 'settings'.
/// Dane przechowywane jako JSON string (brak type adapters = brak code gen).
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static final _log = AppLogger.get('StorageService');

  late Box<String> _subscriptionsBox;
  late Box<String> _categoriesBox;
  late Box<String> _paymentMethodsBox;
  late Box<String> _budgetEntriesBox;
  late Box<String> _householdBudgetEntriesBox;
  late Box<bool> _paymentDoneBox;
  late Box<dynamic> _settingsBox;

  // In-memory cache
  final Map<String, Subscription> _subscriptionsCache = {};
  final Map<String, Category> _categoriesCache = {};
  final Map<String, PaymentMethod> _paymentMethodsCache = {};
  final Map<String, BudgetEntry> _budgetEntriesCache = {};
  final Map<String, BudgetEntry> _householdBudgetEntriesCache = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _subscriptionsBox = await Hive.openBox<String>('subscriptions');
    _categoriesBox = await Hive.openBox<String>('categories');
    _paymentMethodsBox = await Hive.openBox<String>('payment_methods');
    _budgetEntriesBox = await Hive.openBox<String>('budget_entries');
    _householdBudgetEntriesBox =
        await Hive.openBox<String>('household_budget_entries');
    _paymentDoneBox = await Hive.openBox<bool>('payment_done');
    _settingsBox = await Hive.openBox('settings');
    _loadSubscriptionsCache();
    _loadCategoriesCache();
    _loadPaymentMethodsCache();
    _loadBudgetEntriesCache();
    _seedDefaultCategories();
    _seedDefaultPaymentMethods();
    _initialized = true;
    _log.info(
        'StorageService initialized (${_subscriptionsCache.length} subs, ${_categoriesCache.length} cats, ${_paymentMethodsCache.length} payment methods, ${_budgetEntriesCache.length}+${_householdBudgetEntriesCache.length} budget entries)');
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

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    _categoriesCache.remove(id);
    _log.info('Deleted category: $id');
  }

  // ── Payment Methods ────────────────────────────────────────────────────────

  void _loadPaymentMethodsCache() {
    _paymentMethodsCache.clear();
    for (final key in _paymentMethodsBox.keys) {
      try {
        final json = jsonDecode(_paymentMethodsBox.get(key as String)!);
        _paymentMethodsCache[key] =
            PaymentMethod.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        _log.warning('Failed to parse payment method $key: $e');
      }
    }
  }

  void _seedDefaultPaymentMethods() {
    if (_paymentMethodsCache.isNotEmpty) return;
    for (final pm in defaultPaymentMethods) {
      _paymentMethodsBox.put(pm.id, jsonEncode(pm.toJson()));
      _paymentMethodsCache[pm.id] = pm;
    }
    _log.info('Seeded ${defaultPaymentMethods.length} default payment methods');
  }

  List<PaymentMethod> getPaymentMethods() {
    final items = _paymentMethodsCache.values.toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(items);
  }

  PaymentMethod? getPaymentMethod(String id) => _paymentMethodsCache[id];

  Future<void> savePaymentMethod(PaymentMethod pm) async {
    await _paymentMethodsBox.put(pm.id, jsonEncode(pm.toJson()));
    _paymentMethodsCache[pm.id] = pm;
  }

  Future<void> deletePaymentMethod(String id) async {
    await _paymentMethodsBox.delete(id);
    _paymentMethodsCache.remove(id);
    _log.info('Deleted payment method: $id');
  }

  // ── Budget entries (per zakres) ──────────────────────────────────────────────
  // Osobisty i domowy to OSOBNE boxy — domowy jest przyszla jednostka synchronizacji.

  Box<String> _budgetBox(BudgetScope scope) => scope == BudgetScope.household
      ? _householdBudgetEntriesBox
      : _budgetEntriesBox;

  Map<String, BudgetEntry> _budgetCache(BudgetScope scope) =>
      scope == BudgetScope.household
          ? _householdBudgetEntriesCache
          : _budgetEntriesCache;

  void _loadBudgetEntriesCache() {
    for (final scope in BudgetScope.values) {
      final box = _budgetBox(scope);
      final cache = _budgetCache(scope)..clear();
      for (final key in box.keys) {
        try {
          final json = jsonDecode(box.get(key as String)!);
          cache[key] = BudgetEntry.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          _log.warning('Failed to parse budget entry $key ($scope): $e');
        }
      }
    }
  }

  List<BudgetEntry> getBudgetEntries(
          [BudgetScope scope = BudgetScope.personal]) =>
      List.unmodifiable(_budgetCache(scope).values);

  BudgetEntry? getBudgetEntry(String id,
          [BudgetScope scope = BudgetScope.personal]) =>
      _budgetCache(scope)[id];

  Future<void> saveBudgetEntry(BudgetEntry entry,
      [BudgetScope scope = BudgetScope.personal]) async {
    await _budgetBox(scope).put(entry.id, jsonEncode(entry.toJson()));
    _budgetCache(scope)[entry.id] = entry;
    _log.info('Saved budget entry ($scope): ${entry.name}');
  }

  Future<void> deleteBudgetEntry(String id,
      [BudgetScope scope = BudgetScope.personal]) async {
    await _budgetBox(scope).delete(id);
    _budgetCache(scope).remove(id);
    _log.info('Deleted budget entry ($scope): $id');
  }

  /// Zastępuje cały zbiór danego zakresu (po scaleniu przy synchronizacji,
  /// ADR-009). W odróżnieniu od [saveBudgetEntry] NIE modyfikuje pozycji —
  /// zachowuje ich `updatedAt`/`deleted` (łącznie z nagrobkami).
  Future<void> replaceBudgetEntries(
      BudgetScope scope, List<BudgetEntry> entries) async {
    final box = _budgetBox(scope);
    final cache = _budgetCache(scope);
    await box.clear();
    cache.clear();
    for (final e in entries) {
      await box.put(e.id, jsonEncode(e.toJson()));
      cache[e.id] = e;
    }
    _log.info('Replaced ${entries.length} budget entries ($scope) [sync]');
  }

  // ── Platnosci „wykonane" (lokalne, poza backupem) ───────────────────────────
  // Klucz: "<scope>|<sourceId>|<YYYY-MM-DD>". Brak wpisu = niewykonane.

  bool isPaymentDone(String key) =>
      _paymentDoneBox.get(key, defaultValue: false) as bool;

  Future<void> setPaymentDone(String key, bool done) async {
    if (done) {
      await _paymentDoneBox.put(key, true);
    } else {
      await _paymentDoneBox.delete(key);
    }
  }

  /// Wszystkie odhaczone płatności (do backupu). Klucz → true.
  Map<String, bool> getAllPaymentDone() {
    final m = <String, bool>{};
    for (final key in _paymentDoneBox.keys) {
      if (_paymentDoneBox.get(key) == true) m['$key'] = true;
    }
    return m;
  }

  /// Przywraca odhaczone płatności z backupu (tylko wpisy `true`).
  Future<void> importPaymentDone(Map<String, bool> entries) async {
    for (final e in entries.entries) {
      if (e.value) await _paymentDoneBox.put(e.key, true);
    }
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

  // ── Notification preferences ───────────────────────────────────────────────

  bool getNotifyTrialReminders() =>
      _settingsBox.get('notifyTrialReminders', defaultValue: true) as bool;

  Future<void> setNotifyTrialReminders(bool value) async =>
      _settingsBox.put('notifyTrialReminders', value);

  bool getNotifyRenewalReminders() =>
      _settingsBox.get('notifyRenewalReminders', defaultValue: true) as bool;

  Future<void> setNotifyRenewalReminders(bool value) async =>
      _settingsBox.put('notifyRenewalReminders', value);

  // ── Personalizacja Dashboardu (full/compact per sekcja) ─────────────────────

  bool getDashboardSummaryCompact() =>
      _settingsBox.get('dashboardSummaryCompact', defaultValue: false) as bool;

  Future<void> setDashboardSummaryCompact(bool value) async =>
      _settingsBox.put('dashboardSummaryCompact', value);

  bool getDashboardSubscriptionsCompact() =>
      _settingsBox.get('dashboardSubscriptionsCompact', defaultValue: false)
          as bool;

  Future<void> setDashboardSubscriptionsCompact(bool value) async =>
      _settingsBox.put('dashboardSubscriptionsCompact', value);

  bool getDashboardMonthCompact() =>
      _settingsBox.get('dashboardMonthCompact', defaultValue: false) as bool;

  Future<void> setDashboardMonthCompact(bool value) async =>
      _settingsBox.put('dashboardMonthCompact', value);

  bool getDashboardPaymentsCompact() =>
      _settingsBox.get('dashboardPaymentsCompact', defaultValue: false) as bool;

  Future<void> setDashboardPaymentsCompact(bool value) async =>
      _settingsBox.put('dashboardPaymentsCompact', value);
}
