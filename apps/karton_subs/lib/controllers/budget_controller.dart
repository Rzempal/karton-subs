import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/budget_service.dart';
import '../services/app_logger.dart';
import 'subscription_controller.dart';

/// Zarządza stanem budżetu (osobisty + domowy) — CRUD pozycji + computed agregaty.
///
/// Aktywny zakres ([scope]) ustawia UI (przełącznik); wszystkie gettery liczą dla
/// niego. Osobisty i domowy to osobne boxy. Przelew do domowego to para spięta
/// `linkId`: koszt w osobistym + lustrzany wpływ w domowym.
/// Czyta subskrypcje danego zakresu jako dodatkowy strumień kosztów.
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

  void refresh() => notifyListeners();

  // ── Zakres aktywny ─────────────────────────────────────────────────────────

  BudgetScope _scope = BudgetScope.personal;
  BudgetScope get scope => _scope;
  bool get isHousehold => _scope == BudgetScope.household;
  void setScope(BudgetScope s) {
    if (_scope == s) return;
    _scope = s;
    notifyListeners();
  }

  Currency get _target {
    final code = _storage.getCurrency();
    return Currency.values.firstWhere(
      (c) => c.name == code || c.label == code,
      orElse: () => Currency.PLN,
    );
  }

  /// Subskrypcje pasujące do aktywnego zakresu (osobiste/domowe).
  SubscriptionScope get _subScope => isHousehold
      ? SubscriptionScope.household
      : SubscriptionScope.personal;
  List<Subscription> get _subsForScope =>
      _storage.getSubscriptions().where((s) => s.scope == _subScope).toList();

  // ── Listy (aktywny zakres) ───────────────────────────────────────────────

  List<BudgetEntry> get all => _storage.getBudgetEntries(_scope);

  /// Wpływy: cykliczne (pensja) + jednorazowe (premia) + wkłady (lustro przelewu w domowym).
  List<BudgetEntry> get incomes =>
      all.where((e) => e.isIncome).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<BudgetEntry> get recurringExpenses =>
      all.where((e) => e.isExpense && !e.isOneTime).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<BudgetEntry> get oneTimeExpenses {
    final list = all.where((e) => e.isOneTime && e.isExpense).toList();
    list.sort((a, b) => (a.month ?? '').compareTo(b.month ?? ''));
    return list;
  }

  // ── Computed agregaty (aktywny zakres, w walucie docelowej) ────────────────

  double get monthlyIncome => _budget.monthlyIncome(all, target: _target);

  double get monthlyBudgetExpenses =>
      _budget.monthlyBudgetExpenses(all, target: _target);

  double get monthlySubscriptionsExpense =>
      _budget.monthlySubscriptionsExpense(_subsForScope, target: _target);

  double get monthlyExpenses =>
      _budget.monthlyRecurringExpenses(all, _subsForScope, target: _target);

  double get monthlySurplus =>
      _budget.monthlySurplus(all, _subsForScope, target: _target);

  double balanceForMonth(String monthKey) =>
      _budget.balanceForMonth(all, _subsForScope, monthKey, target: _target);

  /// Mapa „nazwa metody platnosci → automatyczna?" (do koloru/listy Platnosci).
  Map<String, bool> get _autoByPayment => {
        for (final pm in _storage.getPaymentMethods()) pm.name: pm.isAutomatic,
      };

  Map<int, DayCashflow> calendarForMonth(DateTime monthStart) =>
      _budget.calendarForMonth(all, _subsForScope, monthStart,
          target: _target, autoByPayment: _autoByPayment);

  // ── Platnosci „wykonane" (lokalne, per zakres + zrodlo + data) ──────────────

  String _paymentKey(String sourceId, DateTime date) {
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '${_scope.name}|$sourceId|$d';
  }

  bool isPaymentDone(String sourceId, DateTime date) =>
      _storage.isPaymentDone(_paymentKey(sourceId, date));

  Future<void> togglePaymentDone(String sourceId, DateTime date) async {
    final key = _paymentKey(sourceId, date);
    await _storage.setPaymentDone(key, !_storage.isPaymentDone(key));
    notifyListeners();
  }

  // ── CRUD (aktywny zakres) ──────────────────────────────────────────────────

  /// Zapis pozycji w aktywnym zakresie (używane m.in. przez import Excel).
  Future<void> add(BudgetEntry entry) async {
    await _storage.saveBudgetEntry(entry, _scope);
    _log.info('Added budget entry ($_scope): ${entry.name}');
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
    String? paymentMethod,
    Map<String, BillMonthOverride>? monthOverrides,
    int? installmentCount,
    DateTime? startDate,
    String? note,
  }) async {
    final now = DateTime.now();

    // Przelew do domowego: para spięta linkId (osobisty wydatek + domowy wpływ).
    if (type == BudgetEntryType.householdTransfer) {
      final linkId = _uuid.v4();
      final personal = BudgetEntry(
        id: _uuid.v4(),
        name: name,
        type: BudgetEntryType.householdTransfer,
        amount: amount,
        currency: currency,
        cycle: cycle,
        customCycleDays: customCycleDays,
        startDate: startDate,
        note: note,
        dataDodania: now,
        linkId: linkId,
      );
      await _storage.saveBudgetEntry(personal, BudgetScope.personal);
      final mirror = BudgetEntry(
        id: _uuid.v4(),
        name: name,
        type: BudgetEntryType.income,
        amount: amount,
        currency: currency,
        cycle: cycle,
        customCycleDays: customCycleDays,
        startDate: startDate,
        note: note ?? 'Z budżetu osobistego',
        dataDodania: now,
        linkId: linkId,
      );
      await _storage.saveBudgetEntry(mirror, BudgetScope.household);
      _log.info('Created household transfer (link $linkId): $name');
      notifyListeners();
      return personal;
    }

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
      paymentMethod: paymentMethod,
      monthOverrides: monthOverrides,
      installmentCount: installmentCount,
      startDate: startDate,
      note: note,
      dataDodania: now,
    );
    await add(entry);
    return entry;
  }

  Future<void> update(BudgetEntry entry) async {
    await _storage.saveBudgetEntry(entry, _scope);
    // Kaskada na lustro w domowym (gdy edytujemy przelew w osobistym).
    if (entry.type == BudgetEntryType.householdTransfer && entry.linkId != null) {
      final mirror = _findByLinkId(entry.linkId!, BudgetScope.household);
      if (mirror != null) {
        await _storage.saveBudgetEntry(
          mirror.copyWith(
            name: entry.name,
            amount: entry.amount,
            cycle: entry.cycle,
            customCycleDays: entry.customCycleDays,
            clearCustomCycleDays: entry.customCycleDays == null,
            startDate: entry.startDate,
            clearStartDate: entry.startDate == null,
            isActive: entry.isActive,
          ),
          BudgetScope.household,
        );
      }
    }
    _log.info('Updated budget entry ($_scope): ${entry.name}');
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final entry = _storage.getBudgetEntry(id, _scope);
    await _storage.deleteBudgetEntry(id, _scope);
    // Kaskada: usuń drugą stronę pary przelewu (w przeciwnym boxie).
    if (entry?.linkId != null) {
      final other = _scope == BudgetScope.personal
          ? BudgetScope.household
          : BudgetScope.personal;
      final partner = _findByLinkId(entry!.linkId!, other);
      if (partner != null) {
        await _storage.deleteBudgetEntry(partner.id, other);
      }
    }
    _log.info('Deleted budget entry ($_scope): $id');
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final entry = _storage.getBudgetEntry(id, _scope);
    if (entry == null) return;
    await update(entry.copyWith(isActive: !entry.isActive));
  }

  BudgetEntry? _findByLinkId(String linkId, BudgetScope scope) {
    for (final e in _storage.getBudgetEntries(scope)) {
      if (e.linkId == linkId) return e;
    }
    return null;
  }
}
