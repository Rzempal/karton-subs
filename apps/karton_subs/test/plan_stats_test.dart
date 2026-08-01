import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/bills_allocation_item.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';

/// Statystyki zakładki „Plan": jeden wykres trendu (trzy rozłączne serie
/// + „Razem") i jeden podział na kategorie dla wszystkich strumieni wydatków.
const _svc = BudgetService();
final _today = DateTime(2026, 7, 15);
final _thisMonth = BudgetEntry.monthKeyOf(_today);

BudgetEntry _recurring(double amount, {String? categoryId}) => BudgetEntry(
      id: 'r_$amount$categoryId',
      name: 'koszt staly',
      type: BudgetEntryType.recurringCost,
      amount: amount,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      categoryId: categoryId,
      dataDodania: _today,
    );

BudgetEntry _bill(double amount, {String? categoryId, String? month}) =>
    BudgetEntry(
      id: 'b_$amount$categoryId',
      name: 'rachunek',
      type: BudgetEntryType.billPayment,
      amount: amount,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      categoryId: categoryId,
      month: month ?? _thisMonth,
      startDate: _today,
      dataDodania: _today,
    );

Subscription _sub(double amount, {String? categoryId}) => Subscription(
      id: 's_$amount$categoryId',
      name: 'sub',
      amount: amount,
      currency: Currency.PLN,
      billingCycle: BillingCycle.monthly,
      startDate: DateTime(2025, 1, 1),
      categoryId: categoryId,
      dataDodania: DateTime(2025, 1, 1),
    );

void main() {
  setUp(() => Subscription.devDateOverride = _today);
  tearDown(() => Subscription.devDateOverride = null);

  group('Trend — trzy serie rozłączne', () {
    final entries = [_recurring(300), _bill(200)];
    final subs = [_sub(50)];

    test('cykliczne = koszty stałe bez subskrypcji i bez rachunków', () {
      final t = _svc.recurringExpenseTrend(entries, view: ExpenseView.plan);
      expect(t.last.amount, closeTo(300, 0.001));
    });

    test('cykliczne są płaskie (brak historii kosztów stałych)', () {
      final t = _svc.recurringExpenseTrend(entries, view: ExpenseView.plan);
      expect(t.length, 6);
      expect(t.every((p) => (p.amount - 300).abs() < 0.001), isTrue);
    });

    test('subskrypcje i rachunki jako osobne strumienie', () {
      expect(
        _svc.subscriptionsTrend(subs, view: ExpenseView.actual).last.amount,
        closeTo(50, 0.001),
      );
      expect(
        _svc.billsTrend(entries, view: ExpenseView.actual).last.amount,
        closeTo(200, 0.001),
      );
    });

    test('suma trzech serii = całość wydatków miesiąca (expenseTrend)', () {
      final sum =
          _svc.recurringExpenseTrend(entries, view: ExpenseView.plan).last.amount +
              _svc.subscriptionsTrend(subs, view: ExpenseView.actual).last.amount +
              _svc.billsTrend(entries, view: ExpenseView.actual).last.amount;
      expect(sum, closeTo(_svc.expenseTrend(entries, subs).last.amount, 0.001));
    });

    test('rachunek innego miesiąca nie wchodzi do bieżącego punktu', () {
      final other = [_recurring(300), _bill(200, month: '2026-05')];
      final t = _svc.billsTrend(other, view: ExpenseView.actual);
      expect(t.last.amount, closeTo(0, 0.001));
    });
  });

  group('Rozpis salda (karta „Saldo" po rozwinięciu)', () {
    final entries = [
      BudgetEntry(
        id: 'i',
        name: 'pensja',
        type: BudgetEntryType.income,
        amount: 8000,
        currency: Currency.PLN,
        cycle: BillingCycle.monthly,
        dataDodania: _today,
      ),
      _recurring(2180),
    ];
    final subs = [_sub(120)];
    const alloc = 500.0;

    test('wpływy − koszty cykliczne − subskrypcje − Planner = saldo', () {
      final income = _svc.monthlyIncome(entries);
      final recurring = _svc.monthlyBudgetExpenses(entries);
      final subsCost = _svc.monthlySubscriptionsExpense(subs);
      final surplus = _svc.monthlySurplus(
        entries,
        subs,
        billsAllocation: alloc,
      );
      expect(income - recurring - subsCost - alloc, closeTo(surplus, 0.001));
      expect(surplus, closeTo(5200, 0.001));
    });

    test('wiersz „Koszty cykliczne" jest bez subskrypcji i bez rezerwy', () {
      // Widok liczy go jako `expenses − allocation − subskrypcje`, bo obie te
      // pozycje mają w rozpisie własne wiersze. Gdyby siedziały w dwóch
      // miejscach naraz, suma wierszy nie zeszłaby się z saldem.
      final expenses = _svc.monthlyRecurringExpenses(entries, subs) + alloc;
      final row = expenses - alloc - _svc.monthlySubscriptionsExpense(subs);
      expect(row, closeTo(2180, 0.001));
    });

    test('cztery wiersze rozpisu sumują się do salda', () {
      final expenses = _svc.monthlyRecurringExpenses(entries, subs) + alloc;
      final subsCost = _svc.monthlySubscriptionsExpense(subs);
      final recurringRow = expenses - alloc - subsCost;
      final surplus = _svc.monthlySurplus(
        entries,
        subs,
        billsAllocation: alloc,
      );
      expect(
        _svc.monthlyIncome(entries) - recurringRow - subsCost - alloc,
        closeTo(surplus, 0.001),
      );
    });
  });

  group('Rzeczywisty bilans miesiąca — rozpis strumieni', () {
    BudgetEntry income(double amount, {Map<String, BillMonthOverride>? overrides}) =>
        BudgetEntry(
          id: 'i$amount',
          name: 'pensja',
          type: BudgetEntryType.income,
          amount: amount,
          currency: Currency.PLN,
          cycle: BillingCycle.monthly,
          monthOverrides: overrides,
          dataDodania: _today,
        );

    test('wpływy − cykliczne − subskrypcje − rachunki = bilans miesiąca', () {
      final entries = [income(8000), _recurring(2180), _bill(950)];
      final subs = [_sub(120)];
      final parts = _svc.monthBalanceParts(entries, subs, _thisMonth);

      expect(parts.income, closeTo(8000, 0.001));
      expect(parts.recurring, closeTo(2180, 0.001));
      expect(parts.subscriptions, closeTo(120, 0.001));
      expect(parts.bills, closeTo(950, 0.001));
      expect(
        parts.balance,
        closeTo(
          _svc.balanceForMonth(entries, subs, _thisMonth, billsAllocation: 500),
          0.001,
        ),
      );
    });

    test('korekta kwoty kosztu wchodzi do kosztów cyklicznych', () {
      final withOverride = _recurring(300).copyWith(
        monthOverrides: {_thisMonth: const BillMonthOverride(amount: 420)},
      );
      final entries = [income(8000), withOverride];
      final parts = _svc.monthBalanceParts(entries, const [], _thisMonth);

      // Plan mówi 300, ten miesiąc realnie 420 — rozpis pokazuje realne 420.
      expect(parts.recurring, closeTo(420, 0.001));
      expect(
        parts.balance,
        closeTo(
          _svc.balanceForMonth(entries, const [], _thisMonth),
          0.001,
        ),
      );
    });

    test('rachunek innego miesiąca nie obciąża tego bilansu', () {
      final entries = [income(8000), _bill(950, month: '2026-05')];
      final parts = _svc.monthBalanceParts(entries, const [], _thisMonth);
      expect(parts.bills, closeTo(0, 0.001));
      expect(parts.balance, closeTo(8000, 0.001));
    });
  });

  group('Podział na kategorie — trzy źródła w jednym wykresie', () {
    test('ta sama kategoria z różnych źródeł sumuje się w jeden wpis', () {
      final r = _svc.combinedExpenseBreakdownByCategory(
        [_recurring(300, categoryId: 'cat_a'), _bill(200, categoryId: 'cat_a')],
        [_sub(50, categoryId: 'cat_a')],
        _thisMonth,
        view: ExpenseView.actual,
      );
      expect(r.length, 1);
      expect(r['cat_a'], closeTo(550, 0.001));
    });

    test('brak kategorii z budżetu i z subskrypcji to jedno „Inne"', () {
      final r = _svc.combinedExpenseBreakdownByCategory(
        [_recurring(300), _bill(200)],
        [_sub(50)],
        _thisMonth,
        view: ExpenseView.actual,
      );
      // Klucz budżetowy „budget_other" jest sprowadzany do „cat_other" —
      // inaczej wykres pokazałby dwa kawałki o tej samej nazwie.
      expect(r.containsKey('budget_other'), isFalse);
      expect(r['cat_other'], closeTo(550, 0.001));
    });

    test('rachunki wchodzą kwotą wybranego miesiąca, nie średnią', () {
      final entries = [_recurring(300), _bill(200, month: '2026-05')];
      final lipiec = _svc.combinedExpenseBreakdownByCategory(
        entries,
        const [],
        '2026-07',
        view: ExpenseView.actual,
      );
      final maj = _svc.combinedExpenseBreakdownByCategory(
        entries,
        const [],
        '2026-05',
        view: ExpenseView.actual,
      );
      expect(lipiec['cat_other'], closeTo(300, 0.001));
      expect(maj['cat_other'], closeTo(500, 0.001));
    });
  });

  // ── Plan vs Rzeczywistość (ADR-028) ────────────────────────────────────────

  group('Trend: plan vs rzeczywistość', () {
    final korekta = _recurring(300).copyWith(
      monthOverrides: {_thisMonth: const BillMonthOverride(amount: 420)},
    );

    test('plan nie zna korekt miesiąca, rzeczywistość je bierze', () {
      final plan = _svc.recurringExpenseTrend([korekta], view: ExpenseView.plan);
      final real = _svc.recurringExpenseTrend(
        [korekta],
        view: ExpenseView.actual,
      );
      expect(plan.last.amount, closeTo(300, 0.001));
      expect(real.last.amount, closeTo(420, 0.001));
      // Miesiąc bez korekty wraca do kwoty bazowej — korekta dotyczy jednego.
      expect(real.first.amount, closeTo(300, 0.001));
    });

    test('rachunki: plan to koperta, rzeczywistość to realne kwoty', () {
      final entries = [_bill(200)];
      final plan = _svc.billsTrend(
        entries,
        view: ExpenseView.plan,
        billsAllocation: 500,
      );
      final real = _svc.billsTrend(entries, view: ExpenseView.actual);
      expect(plan.every((p) => (p.amount - 500).abs() < 0.001), isTrue);
      expect(real.last.amount, closeTo(200, 0.001));
      expect(real.first.amount, closeTo(0, 0.001));
    });

    test('koszt stały dodany w tym miesiącu nie obciąża wstecz (realne)', () {
      // Data startu = jedyny ślad historii, jaki mamy: pozycja z lipca nie
      // istniała w marcu, więc w ujęciu realnym marzec musi być bez niej.
      final swiezy = _recurring(300).copyWith(startDate: _today);
      final real = _svc.recurringExpenseTrend(
        [swiezy],
        view: ExpenseView.actual,
      );
      expect(real.last.amount, closeTo(300, 0.001));
      expect(real.first.amount, closeTo(0, 0.001));
      // W planie ta sama pozycja jest płaska na całym wykresie.
      final plan = _svc.recurringExpenseTrend([swiezy], view: ExpenseView.plan);
      expect(plan.every((p) => (p.amount - 300).abs() < 0.001), isTrue);
    });

    test('rzeczywistość bieżącego miesiąca zgadza się z bilansem miesiąca', () {
      final entries = [korekta, _bill(950)];
      final subs = [_sub(120)];
      final parts = _svc.monthBalanceParts(entries, subs, _thisMonth);
      final real = _svc.recurringExpenseTrend(
        entries,
        view: ExpenseView.actual,
      );
      // Ta sama definicja kosztów cyklicznych po obu stronach — inaczej wykres
      // i bilans pokazywałyby dwie różne prawdy o tym samym miesiącu.
      expect(real.last.amount, closeTo(parts.recurring, 0.001));
      expect(
        _svc.billsTrend(entries, view: ExpenseView.actual).last.amount,
        closeTo(parts.bills, 0.001),
      );
    });
  });

  group('Kategorie: plan vs rzeczywistość', () {
    final alloc = [
      const BillsAllocationItem(
        id: 'a1',
        name: 'Paliwo',
        amount: 300,
        categoryId: 'cat_a',
      ),
      const BillsAllocationItem(id: 'a2', name: 'Bufor', amount: 200),
    ];

    test('plan bierze kopertę (po jej kategoriach), a nie rachunki', () {
      final entries = [_recurring(300, categoryId: 'cat_a'), _bill(950)];
      final r = _svc.combinedExpenseBreakdownByCategory(
        entries,
        const [],
        _thisMonth,
        view: ExpenseView.plan,
        allocationItems: alloc,
      );
      expect(r['cat_a'], closeTo(600, 0.001)); // 300 koszt + 300 koperta
      expect(r['cat_other'], closeTo(200, 0.001)); // bufor bez kategorii
      // Realny rachunek 950 nie ma prawa wejść do ujęcia planowego.
      expect(r.values.fold(0.0, (a, b) => a + b), closeTo(800, 0.001));
    });

    test('rzeczywistość bierze rachunki miesiąca i korekty kosztów', () {
      final entries = [
        _recurring(300, categoryId: 'cat_a').copyWith(
          monthOverrides: {_thisMonth: const BillMonthOverride(amount: 420)},
        ),
        _bill(950, categoryId: 'cat_b'),
      ];
      final r = _svc.combinedExpenseBreakdownByCategory(
        entries,
        const [],
        _thisMonth,
        view: ExpenseView.actual,
        allocationItems: alloc,
      );
      expect(r['cat_a'], closeTo(420, 0.001));
      expect(r['cat_b'], closeTo(950, 0.001));
      // Koperta jest planem — w ujęciu realnym nie występuje.
      expect(r.containsKey('cat_other'), isFalse);
    });
  });
}
