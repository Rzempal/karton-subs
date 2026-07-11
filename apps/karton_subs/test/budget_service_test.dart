import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';

const _svc = BudgetService();
final _date = DateTime(2026, 1, 1);

BudgetEntry _entry({
  required BudgetEntryType type,
  required double amount,
  Currency currency = Currency.PLN,
  BillingCycle cycle = BillingCycle.monthly,
  int? customCycleDays,
  String? month,
  bool isActive = true,
}) =>
    BudgetEntry(
      id: 'e_${type.name}_$amount',
      name: type.name,
      type: type,
      amount: amount,
      currency: currency,
      cycle: cycle,
      customCycleDays: customCycleDays,
      month: month,
      isActive: isActive,
      dataDodania: _date,
    );

Subscription _sub(double amount, {bool active = true}) => Subscription(
      id: 's_$amount',
      name: 'sub',
      amount: amount,
      currency: Currency.PLN,
      billingCycle: BillingCycle.monthly,
      startDate: _date,
      isActive: active,
      dataDodania: _date,
    );

void main() {
  group('BudgetService — normalizacja cyklu (monthlyIncome)', () {
    test('miesięczny = kwota', () {
      final r = _svc.monthlyIncome(
          [_entry(type: BudgetEntryType.income, amount: 5000)]);
      expect(r, closeTo(5000, 0.001));
    });

    test('roczny = kwota / 12', () {
      final r = _svc.monthlyIncome([
        _entry(
            type: BudgetEntryType.income,
            amount: 1200,
            cycle: BillingCycle.yearly)
      ]);
      expect(r, closeTo(100, 0.001));
    });

    test('tygodniowy = kwota * 52 / 12', () {
      final r = _svc.monthlyIncome([
        _entry(
            type: BudgetEntryType.income,
            amount: 100,
            cycle: BillingCycle.weekly)
      ]);
      expect(r, closeTo(100 * 52 / 12, 0.001));
    });

    test('kwartalny = kwota / 3', () {
      final r = _svc.monthlyIncome([
        _entry(
            type: BudgetEntryType.income,
            amount: 300,
            cycle: BillingCycle.quarterly)
      ]);
      expect(r, closeTo(100, 0.001));
    });

    test('własny cykl: kwota * 30 / dni', () {
      final r = _svc.monthlyIncome([
        _entry(
            type: BudgetEntryType.income,
            amount: 70,
            cycle: BillingCycle.custom,
            customCycleDays: 14)
      ]);
      expect(r, closeTo(70 * 30 / 14, 0.001));
    });
  });

  group('BudgetService — surplus i koszty', () {
    test('surplus = wpływy − (koszty cykliczne budżetu + subskrypcje)', () {
      final entries = [
        _entry(type: BudgetEntryType.income, amount: 5000),
        _entry(type: BudgetEntryType.recurringCost, amount: 1500),
        _entry(type: BudgetEntryType.recurringCost, amount: 200),
      ];
      final subs = [_sub(50)];

      expect(_svc.monthlyIncome(entries), closeTo(5000, 0.001));
      expect(_svc.monthlyBudgetExpenses(entries), closeTo(1700, 0.001));
      expect(_svc.monthlySubscriptionsExpense(subs), closeTo(50, 0.001));
      expect(_svc.monthlyRecurringExpenses(entries, subs), closeTo(1750, 0.001));
      expect(_svc.monthlySurplus(entries, subs), closeTo(3250, 0.001));
    });

    test('wydatek jednorazowy nie wchodzi do średniej miesięcznej', () {
      final entries = [
        _entry(type: BudgetEntryType.income, amount: 5000),
        _entry(
            type: BudgetEntryType.oneTimeExpense,
            amount: 3000,
            month: '2026-07'),
      ];
      expect(_svc.monthlyBudgetExpenses(entries), closeTo(0, 0.001));
      expect(_svc.monthlySurplus(entries, const []), closeTo(5000, 0.001));
    });

    test('pozycje wstrzymane (isActive=false) są pomijane', () {
      final entries = [
        _entry(type: BudgetEntryType.income, amount: 5000),
        _entry(type: BudgetEntryType.recurringCost, amount: 1000, isActive: false),
      ];
      expect(_svc.monthlyBudgetExpenses(entries), closeTo(0, 0.001));
      expect(_svc.monthlySurplus(entries, const []), closeTo(5000, 0.001));
    });

    test('nieaktywna subskrypcja nie liczy się do kosztów', () {
      final subs = [_sub(50), _sub(99, active: false)];
      expect(_svc.monthlySubscriptionsExpense(subs), closeTo(50, 0.001));
    });
  });

  group('BudgetService — bilans miesiąca (hybryda)', () {
    final entries = [
      _entry(type: BudgetEntryType.income, amount: 5000),
      _entry(type: BudgetEntryType.recurringCost, amount: 1500),
      _entry(
          type: BudgetEntryType.oneTimeExpense, amount: 3000, month: '2026-07'),
    ];

    test('miesiąc z jednorazowym: bilans = surplus − jednorazowe', () {
      // surplus = 5000 - 1500 = 3500; lipiec ma jednorazowy 3000 → 500
      expect(_svc.balanceForMonth(entries, const [], '2026-07'),
          closeTo(500, 0.001));
    });

    test('miesiąc bez jednorazowego: bilans = surplus', () {
      expect(_svc.balanceForMonth(entries, const [], '2026-08'),
          closeTo(3500, 0.001));
    });

    test('oneTimeTotalForMonth sumuje tylko wskazany miesiąc', () {
      expect(_svc.oneTimeTotalForMonth(entries, '2026-07'),
          closeTo(3000, 0.001));
      expect(_svc.oneTimeTotalForMonth(entries, '2026-08'), closeTo(0, 0.001));
    });

    test('jednorazowy wpływ (premia) podnosi bilans tego miesiąca', () {
      final withBonus = [
        _entry(type: BudgetEntryType.income, amount: 5000),
        _entry(
            type: BudgetEntryType.oneTimeIncome,
            amount: 2000,
            month: '2026-07'),
      ];
      // Nie wchodzi do średniej miesięcznej.
      expect(_svc.monthlyIncome(withBonus), closeTo(5000, 0.001));
      // Lipiec: 5000 + 2000; sierpień: 5000.
      expect(_svc.balanceForMonth(withBonus, const [], '2026-07'),
          closeTo(7000, 0.001));
      expect(_svc.balanceForMonth(withBonus, const [], '2026-08'),
          closeTo(5000, 0.001));
    });
  });

  group('BudgetService — rozbicie bilansu (balanceBreakdownForMonth)', () {
    final entries = [
      _entry(type: BudgetEntryType.income, amount: 5000),
      _entry(type: BudgetEntryType.recurringCost, amount: 1500),
      _entry(
          type: BudgetEntryType.oneTimeExpense, amount: 3000, month: '2026-07'),
      _entry(
          type: BudgetEntryType.oneTimeIncome, amount: 2000, month: '2026-07'),
    ];

    test('suma delt == bilans − saldo (lipiec)', () {
      final diff = _svc.balanceForMonth(entries, const [], '2026-07') -
          _svc.monthlySurplus(entries, const []);
      final sum = _svc
          .balanceBreakdownForMonth(entries, '2026-07')
          .fold<double>(0, (s, it) => s + it.delta);
      expect(sum, closeTo(diff, 0.001));
    });

    test('rozbicie zawiera jednorazowy wpływ (+) i wydatek (−)', () {
      final items = _svc.balanceBreakdownForMonth(entries, '2026-07');
      final income = items.firstWhere(
          (it) => it.kind == BalanceContributionKind.oneTimeIncome);
      final expense = items.firstWhere(
          (it) => it.kind == BalanceContributionKind.oneTimeExpense);
      expect(income.delta, closeTo(2000, 0.001));
      expect(expense.delta, closeTo(-3000, 0.001));
    });

    test('miesiąc bez różnic: pusta lista', () {
      expect(_svc.balanceBreakdownForMonth(entries, '2026-08'), isEmpty);
    });
  });

  group('BudgetService — konwersja walut', () {
    test('wpływ w EUR przeliczony na PLN (kurs 4.28)', () {
      final r = _svc.monthlyIncome(
        [_entry(type: BudgetEntryType.income, amount: 1000, currency: Currency.EUR)],
        target: Currency.PLN,
      );
      expect(r, closeTo(4280, 0.001));
    });
  });
}
