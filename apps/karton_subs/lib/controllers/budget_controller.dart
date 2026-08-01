import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_entry.dart';
import '../models/bills_allocation_item.dart';
import '../models/subscription.dart';
import '../utils/dictionary_usage.dart';
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
    // Tryb budżetu (preferencja UI) wymusza zakres startowy w trybie jednym.
    _mode = _storage.getBudgetMode();
    _scope = _scopeForMode(_mode) ?? _scope;
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
    // W trybie jednozakresowym zakres jest zablokowany (przełącznik ukryty).
    if (!scopeSelectable || _scope == s) return;
    _scope = s;
    notifyListeners();
  }

  // ── Tryb budżetu (Osobisty / Domowy / oba) ─────────────────────────────────

  BudgetMode _mode = BudgetMode.both;
  BudgetMode get budgetMode => _mode;

  /// Czy użytkownik może przełączać zakres (tryb „oba"). W trybie jednym
  /// przełącznik zakresu jest ukryty, a swipe zwalnia się na zakładki 2. rzędu.
  bool get scopeSelectable => _mode == BudgetMode.both;

  /// Wymuszony zakres dla trybu (null dla „oba" — zakres wybiera użytkownik).
  BudgetScope? _scopeForMode(BudgetMode m) => switch (m) {
        BudgetMode.personalOnly => BudgetScope.personal,
        BudgetMode.householdOnly => BudgetScope.household,
        BudgetMode.both => null,
      };

  Future<void> setBudgetMode(BudgetMode m) async {
    if (_mode == m) return;
    _mode = m;
    await _storage.setBudgetMode(m);
    // W trybie jednym wymuś odpowiedni zakres (pomijając blokadę setScope).
    final forced = _scopeForMode(m);
    if (forced != null) _scope = forced;
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
  SubscriptionScope get _subScope =>
      isHousehold ? SubscriptionScope.household : SubscriptionScope.personal;
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
          .where(
            (e) =>
                e.isExpense &&
                !e.isOneTime &&
                e.type != BudgetEntryType.householdTransfer,
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Przelewy do budżetu domowego (tylko zakres osobisty) — sekcja „Przelew wewnętrzny".
  List<BudgetEntry> get internalTransfers =>
      all.where((e) => e.type == BudgetEntryType.householdTransfer).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Subskrypcje aktywnego zakresu — na liście „Wydatki" są trzecią sekcją obok
  /// przelewu wewnętrznego i wydatków stałych (ADR-027). Przypięte na górze,
  /// tak jak na dawnym ekranie „Subskrypcje".
  List<Subscription> get subscriptions => _subsForScope;

  /// Kwota miesięczna subskrypcji w walucie docelowej. Trwający okres próbny
  /// liczy się jako 0 — tak samo jak w planie i na wykresach.
  double monthlySubscriptionAmount(Subscription s) =>
      _currency.convertMonthlyAmount(s, _target);

  /// Suma subskrypcji do nagłówka sekcji — tylko aktywne, bo tylko one wchodzą
  /// do planu. Anulowana subskrypcja bywa na liście widoczna („pokaż ukryte"),
  /// ale nic nie kosztuje.
  double sumSubscriptions(List<Subscription> subs) => subs
      .where((s) => s.isActive)
      .fold(0.0, (sum, s) => sum + monthlySubscriptionAmount(s));

  /// Suma pozycji w walucie docelowej — do nagłówka sekcji. Cykliczne
  /// znormalizowane do kwoty/mies; jednorazowe liczone pełną kwotą (mają sens
  /// tylko jako jednorazowy wydatek, `monthlyAmount` = 0).
  double sumAmounts(List<BudgetEntry> entries) => entries.fold(
    0.0,
    (sum, e) =>
        sum +
        _currency.convert(
          e.isOneTime ? e.amount : e.monthlyAmount,
          e.currency,
          _target,
        ),
  );

  /// Waluta docelowa (kod) — do formatowania w UI.
  String get targetCurrencyLabel => _target.label;

  /// Rachunki ([BudgetEntryType.billPayment]) aktywnego zakresu — najnowsze
  /// u góry (ekran „Rachunki"). Obejmuje wydatki jednorazowe: po scaleniu
  /// typów (ADR-018) to jeden byt — datowany wydatek poza planem.
  List<BudgetEntry> get billPayments {
    final list = all
        .where((e) => e.type == BudgetEntryType.billPayment)
        .toList();
    list.sort(
      (a, b) => (b.startDate ?? b.dataDodania).compareTo(
        a.startDate ?? a.dataDodania,
      ),
    );
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

  double get monthlySurplus => _budget.monthlySurplus(
    all,
    _subsForScope,
    target: _target,
    billsAllocation: _alloc,
  );

  /// Bilans miesiąca rozbity na strumienie (sekcja „Rzeczywisty bilans").
  MonthBalanceParts monthBalanceParts(String monthKey) =>
      _budget.monthBalanceParts(all, _subsForScope, monthKey, target: _target);

  double balanceForMonth(String monthKey) => _budget.balanceForMonth(
    all,
    _subsForScope,
    monthKey,
    target: _target,
    billsAllocation: _alloc,
  );

  /// Pozycje, które sprawiają, że bilans miesiąca różni się od salda planu
  /// (jednorazowe, korekty kwot i rat, rezerwa „Na rachunki"). Do bottom sheeta.
  List<BalanceContribution> balanceBreakdownForMonth(String monthKey) =>
      _budget.balanceBreakdownForMonth(
        all,
        monthKey,
        target: _target,
        billsAllocation: _alloc,
      );

  // ── Rachunki: koperta „Na rachunki" (plan) vs realne rachunki ──────────────

  /// Suma „Na rachunki" (plan/koperta) aktywnego zakresu. `null` = nie ustawiono.
  double? get billsAllocation => _storage.getBillsAllocation(_scope);

  /// Wartość koperty do obliczeń (0 gdy nieustawiona).
  double get _alloc => billsAllocation ?? 0;

  /// Pozycje koperty „Na rachunki" aktywnego zakresu (nazwa + kwota + metoda).
  List<BillsAllocationItem> get billsAllocationItems =>
      _storage.getBillsAllocationItems(_scope);

  /// Pozycje Plannera z nagrobkami — podstawa KAZDEJ mutacji. Budowanie nowej
  /// listy z widocznych pozycji gubiloby nagrobki, a wtedy usuniecie przestaloby
  /// docierac do drugiego telefonu (ADR-022).
  List<BillsAllocationItem> get _allocRaw =>
      _storage.getBillsAllocationItemsRaw(_scope);

  Future<void> addBillsAllocationItem({
    required String name,
    required double amount,
    String? paymentMethod,
    String? categoryId,
  }) async {
    final items = [
      ..._allocRaw,
      BillsAllocationItem(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        updatedAt: DateTime.now(),
        paymentMethod: paymentMethod,
        categoryId: categoryId,
      ),
    ];
    await _saveAllocation(items);
  }

  Future<void> updateBillsAllocationItem(BillsAllocationItem item) async {
    final stamped = item.copyWith(updatedAt: DateTime.now());
    final items = _allocRaw
        .map((e) => e.id == item.id ? stamped : e)
        .toList();
    await _saveAllocation(items);
  }

  /// Usuwa pozycję Plannera. W zakresie DOMOWYM zostawia nagrobek, by usunięcie
  /// dotarło do drugiego telefonu; w osobistym (bez synchronizacji) kasuje twardo.
  Future<void> removeBillsAllocationItem(String id) async {
    final items = isHousehold
        ? _allocRaw
            .map(
              (e) => e.id == id
                  ? e.copyWith(deleted: true, updatedAt: DateTime.now())
                  : e,
            )
            .toList()
        : _allocRaw.where((e) => e.id != id).toList();
    await _saveAllocation(items);
  }

  /// Zapis Plannera + powiadomienie UI; w zakresie domowym wyzwala też
  /// synchronizację (ADR-022 — Planner jedzie w tej samej paczce co pozycje).
  Future<void> _saveAllocation(List<BillsAllocationItem> items) async {
    await _storage.setBillsAllocationItems(_scope, items);
    _notifyMutation(touchedHousehold: isHousehold);
  }

  // ── Słowniki: użycie i kaskady (Kategorie / Metody płatności) ───────────────
  // Kategorie i metody płatności są współdzielone przez oba zakresy budżetu oraz
  // pozycje „Na rachunki". Zarządzanie słownikami (Ustawienia) jest globalne, więc
  // te operacje działają PONAD oboma zakresami, niezależnie od aktywnego.

  /// Liczba pozycji budżetu (oba zakresy, bez nagrobków) oraz pozycji koperty
  /// „Na rachunki" (oba zakresy) w danej kategorii.
  int countCategoryUsage(String categoryId) {
    var n = 0;
    for (final scope in BudgetScope.values) {
      n += DictionaryUsage.categoryInEntries(
        _storage.getBudgetEntries(scope),
        categoryId,
      );
      n += DictionaryUsage.categoryInItems(
        _storage.getBillsAllocationItems(scope),
        categoryId,
      );
    }
    return n;
  }

  /// Liczba użyć metody płatności (po nazwie) w pozycjach budżetu (oba zakresy)
  /// oraz w kopertach „Na rachunki" (oba zakresy).
  int countPaymentMethodUsage(String name) {
    var n = 0;
    for (final scope in BudgetScope.values) {
      n += DictionaryUsage.methodInEntries(
        _storage.getBudgetEntries(scope),
        name,
      );
      n += DictionaryUsage.methodInItems(
        _storage.getBillsAllocationItems(scope),
        name,
      );
    }
    return n;
  }

  /// Przenosi pozycje budżetu (oba zakresy) oraz pozycje koperty „Na rachunki"
  /// (oba zakresy, lokalne — bez synchronizacji) z kategorii [fromId] do [toId].
  /// Zwraca liczbę zmienionych pozycji. Wywoływane przy usunięciu kategorii.
  Future<int> reassignCategoryEverywhere(String fromId, String toId) async {
    var affected = 0;
    var touchedHousehold = false;
    for (final scope in BudgetScope.values) {
      final entries = _storage
          .getBudgetEntries(scope)
          .where((e) => !e.deleted && e.categoryId == fromId)
          .toList();
      for (final e in entries) {
        await _saveStamped(e.copyWith(categoryId: toId), scope);
      }
      if (entries.isNotEmpty) {
        affected += entries.length;
        if (scope == BudgetScope.household) touchedHousehold = true;
      }
      final items = _storage.getBillsAllocationItems(scope);
      final hit = items.where((i) => i.categoryId == fromId).length;
      if (hit > 0) {
        await _storage.setBillsAllocationItems(
          scope,
          items
              .map(
                (i) => i.categoryId == fromId
                    ? i.copyWith(categoryId: toId)
                    : i,
              )
              .toList(),
        );
        affected += hit;
      }
    }
    if (affected > 0) _notifyMutation(touchedHousehold: touchedHousehold);
    return affected;
  }

  /// Zmienia nazwę metody płatności wszędzie w budżecie: pozycje (oba zakresy)
  /// i koperty „Na rachunki" (oba zakresy). Zwraca liczbę zmienionych.
  Future<int> renamePaymentMethodEverywhere(
    String oldName,
    String newName,
  ) async {
    if (oldName == newName) return 0;
    var affected = 0;
    var touchedHousehold = false;
    for (final scope in BudgetScope.values) {
      final entries = _storage
          .getBudgetEntries(scope)
          .where((e) => !e.deleted && e.paymentMethod == oldName)
          .toList();
      for (final e in entries) {
        await _saveStamped(e.copyWith(paymentMethod: newName), scope);
      }
      if (entries.isNotEmpty) {
        affected += entries.length;
        if (scope == BudgetScope.household) touchedHousehold = true;
      }
      // Koperty „Na rachunki" — lokalne (bez synchronizacji).
      final items = _storage.getBillsAllocationItems(scope);
      final hit = items.where((i) => i.paymentMethod == oldName).length;
      if (hit > 0) {
        await _storage.setBillsAllocationItems(
          scope,
          items
              .map(
                (i) => i.paymentMethod == oldName
                    ? i.copyWith(paymentMethod: newName)
                    : i,
              )
              .toList(),
        );
        affected += hit;
      }
    }
    if (affected > 0) _notifyMutation(touchedHousehold: touchedHousehold);
    return affected;
  }

  /// Czyści metodę płatności (po nazwie) wszędzie w budżecie: pozycje (oba
  /// zakresy) i koperty „Na rachunki" (oba zakresy). Zwraca liczbę zmienionych.
  Future<int> clearPaymentMethodEverywhere(String name) async {
    var affected = 0;
    var touchedHousehold = false;
    for (final scope in BudgetScope.values) {
      final entries = _storage
          .getBudgetEntries(scope)
          .where((e) => !e.deleted && e.paymentMethod == name)
          .toList();
      for (final e in entries) {
        await _saveStamped(e.copyWith(clearPaymentMethod: true), scope);
      }
      if (entries.isNotEmpty) {
        affected += entries.length;
        if (scope == BudgetScope.household) touchedHousehold = true;
      }
      final items = _storage.getBillsAllocationItems(scope);
      final hit = items.where((i) => i.paymentMethod == name).length;
      if (hit > 0) {
        await _storage.setBillsAllocationItems(
          scope,
          items
              .map(
                (i) => i.paymentMethod == name
                    ? i.copyWith(clearPaymentMethod: true)
                    : i,
              )
              .toList(),
        );
        affected += hit;
      }
    }
    if (affected > 0) _notifyMutation(touchedHousehold: touchedHousehold);
    return affected;
  }

  /// Suma realnych rachunków ([billPayment]) danego miesiąca w walucie docelowej.
  double billsActualForMonth(String monthKey) =>
      _budget.billsActualForMonth(all, monthKey, target: _target);

  // ── Statystyki (Plan): trendy i podział na kategorie ────────────────────────

  List<MonthlyDataPoint> get budgetExpenseTrend =>
      _budget.expenseTrend(all, _subsForScope, target: _target);

  /// Liczba aktywnych subskrypcji aktywnego zakresu (podsumowanie w karcie
  /// „Saldo" — subskrypcje są częścią kosztów cyklicznych).
  int get activeSubscriptionsCount =>
      _subsForScope.where((s) => s.isActive).length;

  /// Rozłączne serie wspólnego wykresu trendu (suma trzech = całość wydatków).
  List<MonthlyDataPoint> get recurringExpenseTrend =>
      _budget.recurringExpenseTrend(all, target: _target);

  List<MonthlyDataPoint> get subscriptionsTrend =>
      _budget.subscriptionsTrend(_subsForScope, target: _target);

  List<MonthlyDataPoint> get billsTrend =>
      _budget.billsTrend(all, target: _target);

  Map<String, double> get expenseByCategory =>
      _budget.expenseBreakdownByCategory(all, target: _target);

  Map<String, double> billsByCategory(String monthKey) =>
      _budget.billsBreakdownByCategory(all, monthKey, target: _target);

  /// Podział całych wydatków miesiąca wg kategorii: cykliczne + subskrypcje
  /// + rachunki tego miesiąca (jeden wykres zamiast trzech osobnych).
  Map<String, double> combinedExpenseByCategory(String monthKey) =>
      _budget.combinedExpenseBreakdownByCategory(
        all,
        _subsForScope,
        monthKey,
        target: _target,
      );

  /// Mapa „nazwa metody platnosci → automatyczna?" (do koloru/listy Platnosci).
  Map<String, bool> get _autoByPayment => {
    for (final pm in _storage.getPaymentMethods()) pm.name: pm.isAutomatic,
  };

  Map<int, DayCashflow> calendarForMonth(DateTime monthStart) =>
      _budget.calendarForMonth(
        all,
        _subsForScope,
        monthStart,
        target: _target,
        autoByPayment: _autoByPayment,
      );

  // ── Platnosci „wykonane" (lokalne, per zakres + zrodlo + data) ──────────────

  String _paymentKey(String sourceId, DateTime date) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-'
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
    Iterable<({String sourceId, DateTime date})> items,
    bool done,
  ) async {
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
  Future<void> _saveStamped(BudgetEntry entry, BudgetScope scope) => _storage
      .saveBudgetEntry(entry.copyWith(updatedAt: DateTime.now()), scope);

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
    List<int>? cycleMonths,
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
        cycleMonths: cycleMonths,
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
        cycleMonths: cycleMonths,
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
      cycleMonths: cycleMonths,
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
    // Rachunek z datą dzisiejszą lub wcześniejszą to log JUŻ zapłaconej
    // pozycji — oznaczamy go od razu jako wykonany, bez ręcznego odhaczania.
    // Rachunek z datą PRZYSZŁĄ to plan: zostaje nieodhaczony, żeby nie udawał
    // zapłaconego (ADR-018). Klucz musi zgadzać się z kalendarzem: sourceId=id,
    // data = dzień płatności (startDate; fallback pierwszy dzień miesiąca).
    if (type == BudgetEntryType.billPayment) {
      final payDate = startDate ??
          (month != null ? DateTime.tryParse('$month-01') : null) ??
          now;
      final today = DateTime(now.year, now.month, now.day);
      if (!DateTime(payDate.year, payDate.month, payDate.day).isAfter(today)) {
        await _storage.setPaymentDone(_paymentKey(entry.id, payDate), true);
      }
    }
    return entry;
  }

  Future<void> update(BudgetEntry entry) async {
    await _saveStamped(entry, _scope);
    // Kaskada na lustro w domowym (gdy edytujemy przelew w osobistym).
    if (entry.type == BudgetEntryType.householdTransfer &&
        entry.linkId != null) {
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
      touchedHousehold:
          _scope == BudgetScope.household ||
          entry.type == BudgetEntryType.householdTransfer,
    );
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
      touchedHousehold: _scope == BudgetScope.household || entry.linkId != null,
    );
  }

  /// Przenosi pozycję do drugiego budżetu (osobisty ↔ domowy). Zwraca `null`
  /// przy powodzeniu albo komunikat, dlaczego się nie da.
  ///
  /// Zakres nie jest polem pozycji, tylko wynika z pudełka, w którym leży —
  /// przeniesienie to zapis w nowym i usunięcie ze starego. Trzy rzeczy, które
  /// muszą pójść razem z nią:
  ///
  /// 1. **Nagrobek przy wyjściu z domowego.** Domowy kasuje przez `deleted`,
  ///    więc zwykłe wyjęcie rekordu skończyłoby się przywróceniem pozycji
  ///    z serwera przy najbliższej synchronizacji — i liczeniem jej w obu
  ///    budżetach naraz.
  /// 2. **Zdjęcie rachunku**, trzymane poza pozycją (mapa po `id`).
  /// 3. **Odhaczenie płatności**, którego klucz zawiera zakres ORAZ `id`.
  ///
  /// Nowe `id` jest celowe: nagrobek zostaje przy starym, więc pozycja nie ma
  /// jak się z nim zderzyć, gdyby kiedyś wróciła.
  Future<String?> moveToScope(String id) async {
    final from = _scope;
    final to = from == BudgetScope.personal
        ? BudgetScope.household
        : BudgetScope.personal;

    final entry = _storage.getBudgetEntry(id, from);
    if (entry == null) return 'Nie znaleziono pozycji do przeniesienia.';
    // Przelew między budżetami to PARA (pozycja + lustro spięte linkId) —
    // przeniesienie jednej strony rozspoiłoby ją z drugą.
    if (entry.linkId != null) {
      return 'Przelewu między budżetami nie da się przenieść — usuń go '
          'i dodaj w docelowym budżecie.';
    }

    final newId = _uuid.v4();
    final moved = entry.copyWith(
      id: newId,
      updatedAt: DateTime.now(),
      deleted: false,
    );
    await _storage.saveBudgetEntry(moved, to);
    await _removeOrTombstone(entry, from);

    final photo = _storage.getReceiptPhotoPath(id);
    if (photo != null) {
      await _storage.setReceiptPhotoPath(newId, photo);
      await _storage.removeReceiptPhotoPath(id);
    }
    await _storage.movePaymentDone('${from.name}|$id|', '${to.name}|$newId|');

    _log.info('Przeniesiono pozycję $id ($from) -> $newId ($to)');
    // Domowy jest po stronie zmiany zawsze: albo tam trafia pozycja, albo
    // zostaje w nim nagrobek do wysłania.
    _notifyMutation(touchedHousehold: true);
    return null;
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
