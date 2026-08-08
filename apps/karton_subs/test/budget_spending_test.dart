import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/services/budget_service.dart';
import 'package:karton_subs/models/subscription.dart';

// Test-strażnik: rachunek (billPayment = realny log opłat) zasila BILANS
// miesiąca, ale NIGDY planu „zostaje/mies" (surplus). Odwrotnie niż koszt
// cykliczny. Chroni rozdział plan vs realny (ADR-008) po scaleniu typów.

const _svc = BudgetService();
final _date = DateTime(2026, 1, 1);

BudgetEntry _spending({
  required double amount,
  required String month,
  bool isActive = true,
}) =>
    BudgetEntry(
      id: 'bp_${month}_$amount',
      name: 'Rachunek $amount',
      type: BudgetEntryType.spending,
      amount: amount,
      currency: Currency.PLN,
      month: month,
      startDate: DateTime.tryParse('$month-15'),
      isActive: isActive,
      dataDodania: _date,
    );

BudgetEntry _income(double amount) => BudgetEntry(
      id: 'inc_$amount',
      name: 'Pensja',
      type: BudgetEntryType.income,
      amount: amount,
      currency: Currency.PLN,
      dataDodania: _date,
    );

void main() {
  group('Rachunki (billPayment) — plan vs bilans (ADR-008)', () {
    test('rachunek NIE wchodzi do „zostaje/mies" (surplus)', () {
      final entries = [_income(5000), _spending(amount: 400, month: '2026-07')];
      // Surplus liczy tylko koszty cykliczne — rachunek to realny log, nie plan.
      expect(_svc.monthlyBudgetExpenses(entries), closeTo(0, 0.001));
      expect(_svc.monthlySurplus(entries, const []), closeTo(5000, 0.001));
    });

    test('rachunek obciąża bilans SWOJEGO miesiąca, nie innych', () {
      final entries = [_income(5000), _spending(amount: 400, month: '2026-07')];
      expect(_svc.balanceForMonth(entries, const [], '2026-07'),
          closeTo(4600, 0.001));
      expect(_svc.balanceForMonth(entries, const [], '2026-08'),
          closeTo(5000, 0.001));
    });

    test('spendingActualForMonth sumuje tylko rachunki danego miesiąca', () {
      final entries = [
        _spending(amount: 400, month: '2026-07'),
        _spending(amount: 150, month: '2026-07'),
        _spending(amount: 999, month: '2026-08'),
      ];
      expect(_svc.spendingActualForMonth(entries, '2026-07'), closeTo(550, 0.001));
      expect(_svc.spendingActualForMonth(entries, '2026-08'), closeTo(999, 0.001));
      expect(_svc.spendingActualForMonth(entries, '2026-09'), closeTo(0, 0.001));
    });

    test('nieaktywny rachunek pomijany w bilansie i sumie', () {
      final entries = [
        _income(5000),
        _spending(amount: 400, month: '2026-07', isActive: false),
      ];
      expect(_svc.spendingActualForMonth(entries, '2026-07'), closeTo(0, 0.001));
      expect(_svc.balanceForMonth(entries, const [], '2026-07'),
          closeTo(5000, 0.001));
    });
  });

  group('Koperta „Na rachunki" (planowany koszt, ADR-011)', () {
    test('koperta pomniejsza surplus, NIE rusza bilansu', () {
      final entries = [_income(5000), _spending(amount: 400, month: '2026-07')];
      // Bez koperty.
      expect(_svc.monthlySurplus(entries, const []), closeTo(5000, 0.001));
      // Koperta 500 → plan mniejszy o 500 (rezerwa na rachunki).
      expect(_svc.monthlySurplus(entries, const [], spendingAllocation: 500),
          closeTo(4500, 0.001));
      // Bilans miesiąca liczy REALNE rachunki (400), niezależnie od koperty.
      expect(
          _svc.balanceForMonth(entries, const [], '2026-07',
              spendingAllocation: 500),
          closeTo(4600, 0.001));
      expect(_svc.balanceForMonth(entries, const [], '2026-07'),
          closeTo(4600, 0.001));
    });

    test('suma rozbicia == bilans − surplus (z kopertą)', () {
      final entries = [_income(5000), _spending(amount: 400, month: '2026-07')];
      final diff = _svc.balanceForMonth(entries, const [], '2026-07',
              spendingAllocation: 500) -
          _svc.monthlySurplus(entries, const [], spendingAllocation: 500);
      final sum = _svc
          .balanceBreakdownForMonth(entries, '2026-07', spendingAllocation: 500)
          .fold<double>(0, (s, it) => s + it.delta);
      expect(sum, closeTo(diff, 0.001));
    });
  });
}
