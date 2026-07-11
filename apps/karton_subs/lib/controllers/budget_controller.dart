import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/budget_service.dart';
import '../services/analytics_service.dart' show MonthlyDataPoint;
import '../services/currency_service.dart';
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
  static const _currency = CurrencyService();

  BudgetController(this._storage, this._subscriptions) {
    _subscriptions.addListener(_onSubscriptionsChanged);
  }

  void _onSubscriptionsChanged() => notifyListeners();

  /// Wywoływane po zmianie dotykającej budżetu domowego — `main` podpina tu
  /// (debounced) synchronizację (ADR-009). `null` = brak synchronizacji.
  void Function()? onHouseholdChanged;

  /// Powiadamia UI i — gdy zmiana dotknęła domowego — wyzwala synchronizację.
  void _notifyMutation({required bool touchedHousehold}) {
    notifyListeners();
    if (touchedHousehold) onHouseholdChanged?.call();
  }

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

  /// Pozycje aktywnego zakresu widoczne dla UI/agregatów — bez nagrobków
  /// (pozycji oznaczonych `deleted` przy synchronizacji domowego, ADR-009).
  List<BudgetEntry> get all =>
      _storage.getBudgetEntries(_scope).where((e) => !e.deleted).toList();

  /// Wpływy: cykliczne (pensja) + jednorazowe (premia) + wkłady (lustro przelewu w domowym).
  List<BudgetEntry> get incomes =>
      all.where((e) => e.isIncome).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Koszty cykliczne (rachunki, koszty cykliczne, raty) — BEZ przelewu do domowego,
  /// który ma własną sekcję „Przelew wewnętrzny".
  List<BudgetEntry> get recurringExpenses =>
      all
          .where((e) =>
              e.isExpense &&
              !e.isOneTime &&
              e.type != BudgetEntryType.householdTransfer)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Przelewy do budżetu domowego (tylko zakres osobisty) — sekcja „Przelew wewnętrzny".
  List<BudgetEntry> get internalTransfers =>
      all.where((e) => e.type == BudgetEntryType.householdTransfer).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Suma pozycji w walucie docelowej — do nagłówka sekcji. Cykliczne
  /// znormalizowane do kwoty/mies; jednorazowe liczone pełną kwotą (mają sens
  /// tylko jako jednorazowy wydatek, `monthlyAmount` = 0).
  double sumAmounts(List<BudgetEntry> entries) => entries.fold(
        0.0,
        (sum, e) => sum +
            _currency.convert(
                e.isOneTime ? e.amount : e.monthlyAmount, e.currency, _target),
      );

  /// Waluta docelowa (kod) — do formatowania w UI.
  String get targetCurrencyLabel => _target.label;

  /// Wydatki jednorazowe (Budżet) — BEZ rachunków ([billPayment]), które mają
  /// własny ekran „Rachunki" mimo tej samej semantyki czasu (jednorazowy wydatek).
  List<BudgetEntry> get oneTimeExpenses {
    final list = all
        .where((e) =>
            e.isOneTime &&
            e.isExpense &&
            e.type != BudgetEntryType.billPayment)
        .toList();
    list.sort((a, b) => (a.month ?? '').compareTo(b.month ?? ''));
    return list;
  }

  /// Rachunki (realny log opłaconych pozycji, [BudgetEntryType.billPayment])
  /// aktywnego zakresu — najnowsze u góry (ekran „Rachunki").
  List<BudgetEntry> get billPayments {
    final list =
        all.where((e) => e.type == BudgetEntryType.billPayment).toList();
    list.sort((a, b) =>
        (b.startDate ?? b.dataDodania).compareTo(a.startDate ?? a.dataDodania));
    return list;
  }

  // ── Computed agregaty (aktywny zakres, w walucie docelowej) ────────────────

  double get monthlyIncome => _budget.monthlyIncome(all, target: _target);

  double get monthlyBudgetExpenses =>
      _budget.monthlyBudgetExpenses(all, target: _target);

  double get monthlySubscriptionsExpense =>
      _budget.monthlySubscriptionsExpense(_subsForScope, target: _target);

  /// Koszty/mies w planie: cykliczne + subskrypcje + rezerwa „Na rachunki".
  /// (Dzięki temu wpływy − koszty = „zostaje/mies".)
  double get monthlyExpenses =>
      _budget.monthlyRecurringExpenses(all, _subsForScope, target: _target) +
      _alloc;

  double get monthlySurplus => _budget.monthlySurplus(all, _subsForScope,
      target: _target, billsAllocation: _alloc);

  double balanceForMonth(String monthKey) => _budget.balanceForMonth(
      all, _subsForScope, monthKey,
      target: _target, billsAllocation: _alloc);

  /// Pozycje, które sprawiają, że bilans miesiąca różni się od salda planu
  /// (jednorazowe, korekty kwot i rat, rezerwa „Na rachunki"). Do bottom sheeta.
  List<BalanceContribution> balanceBreakdownForMonth(String monthKey) =>
      _budget.balanceBreakdownForMonth(all, monthKey,
          target: _target, billsAllocation: _alloc);

  // ── Rachunki: koperta „Na rachunki" (plan) vs realne rachunki ──────────────

  /// Kwota „Na rachunki" (plan/koperta) aktywnego zakresu. `null` = nie ustawiono.
  double? get billsAllocation => _storage.getBillsAllocation(_scope);

  /// Wartość koperty do obliczeń (0 gdy nieustawiona).
  double get _alloc => billsAllocation ?? 0;

  Future<void> setBillsAllocation(double? amount) async {
    await _storage.setBillsAllocation(_scope, amount);
    notifyListeners();
  }

  /// Suma realnych rachunków ([billPayment]) danego miesiąca w walucie docelowej.
  double billsActualForMonth(String monthKey) =>
      _budget.billsActualForMonth(all, monthKey, target: _target);

  // ── Statystyki (Plan): trendy i podział na kategorie ────────────────────────

  List<MonthlyDataPoint> get budgetExpenseTrend =>
      _budget.expenseTrend(all, _subsForScope, target: _target);

  List<MonthlyDataPoint> get billsTrend =>
      _budget.billsTrend(all, target: _target);

  Map<String, double> get expenseByCategory =>
      _budget.expenseBreakdownByCategory(all, target: _target);

  Map<String, double> billsByCategory(String monthKey) =>
      _budget.billsBreakdownByCategory(all, monthKey, target: _target);

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

  /// Ustawia stan „wykonane" dla wielu płatności naraz (przycisk „odhacz
  /// wszystkie" w grupie płatności miesiąca). Jedno powiadomienie na koniec.
  Future<void> setPaymentsDone(
      Iterable<({String sourceId, DateTime date})> items, bool done) async {
    for (final it in items) {
      await _storage.setPaymentDone(_paymentKey(it.sourceId, it.date), done);
    }
    notifyListeners();
  }

  // ── CRUD (aktywny zakres) ──────────────────────────────────────────────────

  /// Zapis pozycji z odświeżeniem znacznika zmiany (`updatedAt`) — podstawa
  /// scalania przy synchronizacji domowego (ADR-009). Hurtowy zapis po scaleniu
  /// idzie osobną ścieżką ([StorageService.replaceBudgetEntries]), by zachować
  /// oryginalne znaczniki.
  Future<void> _saveStamped(BudgetEntry entry, BudgetScope scope) =>
      _storage.saveBudgetEntry(entry.copyWith(updatedAt: DateTime.now()), scope);

  /// Zapis pozycji w aktywnym zakresie (używane m.in. przez import Excel).
  Future<void> add(BudgetEntry entry) async {
    await _saveStamped(entry, _scope);
    _log.info('Added budget entry ($_scope): ${entry.name}');
    _notifyMutation(touchedHousehold: _scope == BudgetScope.household);
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
        monthOverrides: monthOverrides,
        note: note,
        dataDodania: now,
        linkId: linkId,
      );
      await _saveStamped(personal, BudgetScope.personal);
      final mirror = BudgetEntry(
        id: _uuid.v4(),
        name: name,
        type: BudgetEntryType.income,
        amount: amount,
        currency: currency,
        cycle: cycle,
        customCycleDays: customCycleDays,
        startDate: startDate,
        monthOverrides: monthOverrides,
        note: note ?? 'Z budżetu osobistego',
        dataDodania: now,
        linkId: linkId,
      );
      await _saveStamped(mirror, BudgetScope.household);
      _log.info('Created household transfer (link $linkId): $name');
      _notifyMutation(touchedHousehold: true); // lustro w domowym
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
    await _saveStamped(entry, _scope);
    // Kaskada na lustro w domowym (gdy edytujemy przelew w osobistym).
    if (entry.type == BudgetEntryType.householdTransfer && entry.linkId != null) {
      final mirror = _findByLinkId(entry.linkId!, BudgetScope.household);
      if (mirror != null) {
        await _saveStamped(
          mirror.copyWith(
            name: entry.name,
            amount: entry.amount,
            cycle: entry.cycle,
            customCycleDays: entry.customCycleDays,
            clearCustomCycleDays: entry.customCycleDays == null,
            startDate: entry.startDate,
            clearStartDate: entry.startDate == null,
            isActive: entry.isActive,
            // Korekty kaskadują do lustra → bilans domowego zgodny z realnie przelaną kwotą.
            monthOverrides: entry.monthOverrides,
            clearMonthOverrides: entry.monthOverrides == null,
          ),
          BudgetScope.household,
        );
      }
    }
    _log.info('Updated budget entry ($_scope): ${entry.name}');
    _notifyMutation(
        touchedHousehold: _scope == BudgetScope.household ||
            entry.type == BudgetEntryType.householdTransfer);
  }

  Future<void> delete(String id) async {
    final entry = _storage.getBudgetEntry(id, _scope);
    if (entry == null) return;
    await _removeOrTombstone(entry, _scope);
    // Kaskada: usuń drugą stronę pary przelewu (w przeciwnym boxie).
    if (entry.linkId != null) {
      final other = _scope == BudgetScope.personal
          ? BudgetScope.household
          : BudgetScope.personal;
      final partner = _findByLinkId(entry.linkId!, other);
      if (partner != null) {
        await _removeOrTombstone(partner, other);
      }
    }
    _log.info('Deleted budget entry ($_scope): $id');
    _notifyMutation(
        touchedHousehold:
            _scope == BudgetScope.household || entry.linkId != null);
  }

  /// Usuwa pozycję: domowy zostawia **nagrobek** (deleted=true), by usunięcie
  /// propagowało się przy synchronizacji; osobisty kasuje twardo (brak sync).
  Future<void> _removeOrTombstone(BudgetEntry entry, BudgetScope scope) async {
    if (scope == BudgetScope.household) {
      await _saveStamped(entry.copyWith(deleted: true), scope);
    } else {
      await _storage.deleteBudgetEntry(entry.id, scope);
    }
  }

  Future<void> toggleActive(String id) async {
    final entry = _storage.getBudgetEntry(id, _scope);
    if (entry == null) return;
    await update(entry.copyWith(isActive: !entry.isActive));
  }

  BudgetEntry? _findByLinkId(String linkId, BudgetScope scope) {
    for (final e in _storage.getBudgetEntries(scope)) {
      if (e.linkId == linkId && !e.deleted) return e;
    }
    return null;
  }
}
