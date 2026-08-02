import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';

/// Podsumowanie roczne (ADR-029) i domykanie planu do pełnej kwoty.
const _svc = BudgetService();
final _today = DateTime(2026, 8, 15); // sierpień = 8. miesiąc

BudgetEntry _recurring(double amount, {DateTime? start}) => BudgetEntry(
  id: 'r$amount${start?.month}',
  name: 'koszt staly',
  type: BudgetEntryType.recurringCost,
  amount: amount,
  currency: Currency.PLN,
  cycle: BillingCycle.monthly,
  startDate: start,
  dataDodania: _today,
);

BudgetEntry _bill(double amount, String month) => BudgetEntry(
  id: 'b$amount$month',
  name: 'rachunek',
  type: BudgetEntryType.billPayment,
  amount: amount,
  currency: Currency.PLN,
  cycle: BillingCycle.monthly,
  month: month,
  startDate: DateTime.parse('$month-10'),
  dataDodania: _today,
);

void main() {
  setUp(() => Subscription.devDateOverride = _today);
  tearDown(() => Subscription.devDateOverride = null);

  group('Podsumowanie roczne — wykonanie planu', () {
    test('realne: przyszłe miesiące są puste, nie zerowe', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000)],
        const [],
        2026,
        view: ExpenseView.actual,
      );
      // Sierpień to ósmy miesiąc — dalej nic jeszcze nie wydano.
      expect(s.months[7].amount, closeTo(1000, 0.001));
      expect(s.months[8].amount, isNull);
      expect(s.months[11].amount, isNull);
      expect(s.spent, closeTo(8000, 0.001));
    });

    test('narastająco = suma miesięcy do danego punktu', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000), _bill(500, '2026-03')],
        const [],
        2026,
        view: ExpenseView.actual,
      );
      expect(s.months[2].amount, closeTo(1500, 0.001)); // marzec z rachunkiem
      expect(s.months[2].cumulative, closeTo(3500, 0.001)); // 1000+1000+1500
      expect(s.spent, closeTo(8500, 0.001));
    });

    test('plan: każdy miesiąc tą samą kwotą, łącznie 12 × plan', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000)],
        const [],
        2026,
        view: ExpenseView.plan,
        billsAllocation: 500,
      );
      expect(s.plannedMonthly, closeTo(1500, 0.001));
      expect(s.months.every((m) => m.amount == 1500), isTrue);
      expect(s.spent, closeTo(18000, 0.001));
      expect(s.planned, closeTo(18000, 0.001));
      expect(s.progress, closeTo(1.0, 0.001));
    });

    test('początek ewidencji: wcześniejsze miesiące puste po OBU stronach', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000)],
        const [],
        2026,
        view: ExpenseView.actual,
        fromMonth: 7, // ewidencja od lipca
      );
      expect(s.months[5].amount, isNull); // czerwiec
      expect(s.months[6].amount, closeTo(1000, 0.001)); // lipiec
      expect(s.spent, closeTo(2000, 0.001)); // lipiec + sierpień
      // Plan liczy tylko lipiec–grudzień, inaczej wykonanie wyszłoby na 17%
      // tylko dlatego, że przez pół roku nie było czego zapisywać.
      expect(s.planned, closeTo(6000, 0.001));
      expect(s.progress, closeTo(2000 / 6000, 0.001));
    });

    test('koszt dodany w trakcie roku nie obciąża miesięcy sprzed startu', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000, start: DateTime(2026, 6, 1))],
        const [],
        2026,
        view: ExpenseView.actual,
      );
      expect(s.months[4].amount, closeTo(0, 0.001)); // maj — jeszcze nie było
      expect(s.months[5].amount, closeTo(1000, 0.001)); // czerwiec
      expect(s.spent, closeTo(3000, 0.001)); // cze + lip + sie
    });

    test('ewidencja od kolejnego roku: rok pusty, bez planu', () {
      final s = _svc.yearExpenseSummary(
        [_recurring(1000)],
        const [],
        2026,
        view: ExpenseView.actual,
        fromMonth: 13,
      );
      expect(s.months.every((m) => m.amount == null), isTrue);
      expect(s.planned, closeTo(0, 0.001));
      expect(s.progress, isNull);
    });
  });

  group('Trend a początek ewidencji', () {
    // Wykres nie ma pokazywać miesięcy sprzed ewidencji: dane wstecz są
    // odtwarzane z dzisiejszych kwot (ADR-028), więc przed startem byłyby
    // po prostu zmyślone.
    final entries = [_recurring(1000)];

    test('bez początku ewidencji: pełne sześć miesięcy', () {
      final t = _svc.recurringExpenseTrend(entries, view: ExpenseView.actual);
      expect(t.length, 6);
      expect(t.first.month, DateTime(2026, 3, 1));
    });

    test('start w lipcu: oś zaczyna się od lipca', () {
      final t = _svc.recurringExpenseTrend(
        entries,
        view: ExpenseView.actual,
        fromMonth: '2026-07',
      );
      expect(t.length, 2);
      expect(t.first.month, DateTime(2026, 7, 1));
      expect(t.last.month, DateTime(2026, 8, 1));
    });

    test('wszystkie serie skracają się tak samo (wspólna oś)', () {
      final r = _svc.recurringExpenseTrend(
        entries,
        view: ExpenseView.actual,
        fromMonth: '2026-07',
      );
      final s = _svc.subscriptionsTrend(
        const [],
        view: ExpenseView.actual,
        fromMonth: '2026-07',
      );
      final b = _svc.billsTrend(
        entries,
        view: ExpenseView.actual,
        fromMonth: '2026-07',
      );
      expect(s.length, r.length);
      expect(b.length, r.length);
      expect(s.first.month, r.first.month);
    });

    test('start po całej osi: zostaje bieżący miesiąc', () {
      final t = _svc.recurringExpenseTrend(
        entries,
        view: ExpenseView.actual,
        fromMonth: '2027-01',
      );
      expect(t.length, 1);
      expect(t.single.month, DateTime(2026, 8, 1));
    });
  });

  group('Uzupełnienie do pełnej kwoty', () {
    test('liczy resztę w groszach, bez błędu zmiennoprzecinkowego', () {
      expect(_svc.roundUpGap(1296.56, 100), closeTo(3.44, 0.0001));
      expect(_svc.roundUpGap(1296.56, 1000), closeTo(703.44, 0.0001));
      expect(_svc.roundUpGap(7987.38, 100), closeTo(12.62, 0.0001));
      expect(_svc.roundUpGap(7987.38, 10), closeTo(2.62, 0.0001));
    });

    test('suma już okrągła → nie ma czego dodawać', () {
      expect(_svc.roundUpGap(1300, 100), 0);
      expect(_svc.roundUpGap(2000, 1000), 0);
      expect(_svc.roundUpGap(0, 100), 0);
    });

    test('po dodaniu reszty suma jest wielokrotnością kroku', () {
      for (final total in [1296.56, 7987.38, 0.01, 999.99]) {
        for (final step in [10, 100, 1000]) {
          final sum = total + _svc.roundUpGap(total, step);
          expect((sum * 100).round() % (step * 100), 0, reason: '$total / $step');
        }
      }
    });
  });
}
