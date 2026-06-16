import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/budget_service.dart';
import '../services/app_logger.dart';
import 'subscription_controller.dart';

/// Zarządza stanem budżetu domowego: CRUD pozycji + computed agregaty.
///
/// Czyta subskrypcje jako dodatkowy strumień kosztów (przez [BudgetService]).
/// Nasłuchuje [SubscriptionController], by odświeżyć UI budżetu, gdy zmienią
/// się subskrypcje (dodanie/edycja/usunięcie wpływa na sumę kosztów).
class BudgetController extends ChangeNotifier {
  static final _log = AppLogger.get('BudgetController');
  final StorageService _storage;
  final SubscriptionController _subscriptions;
  static const _uuid = Uuid();
  static const _budget = BudgetService();

  BudgetController(this._storage, this._subscriptions) {
    _subscriptions.addListener(_onSubscriptionsChanged);
  }

  void _onSubscriptionsChanged() => notifyListeners();

  @override
  void dispose() {
    _subscriptions.removeListener(_onSubscriptionsChanged);
    super.dispose();
  }

  /// Wymusza odświeżenie (np. po zmianie waluty w ustawieniach).
  void refresh() => notifyListeners();

  Currency get _target {
    final code = _storage.getCurrency();
    return Currency.values.firstWhere(
      (c) => c.name == code || c.label == code,
      orElse: () => Currency.PLN,
    );
  }

  List<Subscription> get _subs => _storage.getSubscriptions();

  // ── Listy ────────────────────────────────────────────────────────────────

  List<BudgetEntry> get all => _storage.getBudgetEntries();

  List<BudgetEntry> get incomes =>
      all.where((e) => e.isIncome && !e.isOneTime).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<BudgetEntry> get recurringExpenses =>
      all.where((e) => e.isExpense && !e.isOneTime).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<BudgetEntry> get oneTimeExpenses {
    final list = all.where((e) => e.isOneTime).toList();
    list.sort((a, b) => (a.month ?? '').compareTo(b.month ?? ''));
    return list;
  }

  // ── Computed agregaty (w walucie docelowej) ──────────────────────────────

  double get monthlyIncome => _budget.monthlyIncome(all, target: _target);

  double get monthlyBudgetExpenses =>
      _budget.monthlyBudgetExpenses(all, target: _target);

  double get monthlySubscriptionsExpense =>
      _budget.monthlySubscriptionsExpense(_subs, target: _target);

  double get monthlyExpenses =>
      _budget.monthlyRecurringExpenses(all, _subs, target: _target);

  double get monthlySurplus =>
      _budget.monthlySurplus(all, _subs, target: _target);

  List<BudgetEntry> oneTimeForMonth(String monthKey) =>
      _budget.oneTimeExpensesForMonth(all, monthKey);

  double oneTimeTotalForMonth(String monthKey) =>
      _budget.oneTimeTotalForMonth(all, monthKey, target: _target);

  double balanceForMonth(String monthKey) =>
      _budget.balanceForMonth(all, _subs, monthKey, target: _target);

  List<BudgetEntry> get upcomingOneTime => _budget.upcomingOneTime(all);

  Map<String, double> get expenseBreakdown =>
      _budget.expenseBreakdownByCategory(all, target: _target);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> add(BudgetEntry entry) async {
    await _storage.saveBudgetEntry(entry);
    _log.info('Added budget entry: ${entry.name}');
    notifyListeners();
  }

  Future<BudgetEntry> create({
    required String name,
    required BudgetEntryType type,
    required double amount,
    required Currency currency,
    BillingCycle cycle = BillingCycle.monthly,
    int? customCycleDays,
    String? month,
    String? categoryId,
    DateTime? startDate,
    String? note,
  }) async {
    final entry = BudgetEntry(
      id: _uuid.v4(),
      name: name,
      type: type,
      amount: amount,
      currency: currency,
      cycle: cycle,
      customCycleDays: customCycleDays,
      month: month,
      categoryId: categoryId,
      startDate: startDate,
      note: note,
      dataDodania: DateTime.now(),
    );
    await add(entry);
    return entry;
  }

  Future<void> update(BudgetEntry entry) async {
    await _storage.saveBudgetEntry(entry);
    _log.info('Updated budget entry: ${entry.name}');
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.deleteBudgetEntry(id);
    _log.info('Deleted budget entry: $id');
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final entry = _storage.getBudgetEntry(id);
    if (entry == null) return;
    await update(entry.copyWith(isActive: !entry.isActive));
  }
}
